//! wavium-work-steal: work-stealing actor scheduler.
//!
//! Every worker owns an independent ready queue (in fact, one
//! `ChaseLevDeque` per priority class - see `priority.zig`). Idle
//! workers steal actors from busy workers rather than sitting idle,
//! using a Chase-Lev deque so the owner's local push/pop path never
//! contends with a thief except for the single last-element race.
//!
//! Requirements covered:
//!   - Chase-Lev deque: `deque.ChaseLevDeque` (fixed-capacity variant).
//!   - Victim selection + randomized stealing: `victim.zig`
//!     (`selectRandomVictim`, backed by a dependency-free xorshift
//!     PRNG since this freestanding runtime has no OS entropy source).
//!   - Priority stealing: `priority.zig` (`PriorityQueues` - both
//!     local pop and steal always try `high` before `normal` before
//!     `low`).
//!   - Fairness + starvation prevention: `fairness.zig` (`tick`
//!     promotes a long-waiting actor to the next priority class up,
//!     bounding worst-case wait time; `RoundRobin` for unbiased
//!     scheduling-round rotation).
//!   - `worker.zig` ties all of the above into a single `Worker` type
//!     matching the prompt's "every worker owns a ready queue" shape.
//!   - `benchmark.zig` provides the required performance benchmarks.

const std = @import("std");
const testing = std.testing;

pub const deque = @import("deque.zig");
pub const victim = @import("victim.zig");
pub const priority = @import("priority.zig");
pub const fairness = @import("fairness.zig");
pub const worker = @import("worker.zig");
pub const benchmark = @import("benchmark.zig");

pub const ChaseLevDeque = deque.ChaseLevDeque;
pub const Rng = victim.Rng;
pub const Priority = priority.Priority;
pub const PriorityQueues = priority.PriorityQueues;
pub const Worker = worker.Worker;

pub fn moduleName() []const u8 {
    return "wavium-work-steal";
}

test "moduleName reports the expected module name" {
    try testing.expectEqualStrings("wavium-work-steal", moduleName());
}

test "end-to-end: an idle worker steals a high-priority actor and starvation aging promotes a stale one" {
    const Cap = 64;
    var workers = [_]Worker(Cap){
        Worker(Cap).init(0, 100),
        Worker(Cap).init(1, 200),
    };

    // Worker 0 is loaded with work; worker 1 starts idle.
    try workers[0].submit(.{ .actor_id = 1, .priority = .low });
    try workers[0].submit(.{ .actor_id = 2, .priority = .high });

    // Idle worker 1 steals - it should get the high-priority actor
    // first, exactly like a local popOwn would have.
    const stolen = workers[1].stealFrom(&workers).?;
    try testing.expectEqual(Priority.high, stolen.priority);
    try testing.expectEqual(@as(worker.ActorId, 2), stolen.actor_id);

    // Worker 0 still owns the low-priority actor and can pop it
    // itself without any contention from worker 1's steal above.
    const own = workers[0].popOwn().?;
    try testing.expectEqual(@as(worker.ActorId, 1), own.actor_id);

    // Starvation prevention: an actor that has waited too long in a
    // low-priority class gets promoted regardless of continued
    // high-priority arrivals.
    var entry = fairness.AgingEntry{ .actor_id = 3, .priority = .low, .wait_ticks = 0 };
    var i: u32 = 0;
    while (i < fairness.promotion_threshold) : (i += 1) entry = fairness.tick(entry);
    try testing.expectEqual(Priority.normal, entry.priority);
}
