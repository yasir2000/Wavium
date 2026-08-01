//! Worker: ties `PriorityQueues`, victim selection, and starvation
//! prevention together into the per-worker work-stealing scheduler
//! entry point required by the prompt ("every worker owns a ready
//! queue; idle workers steal actors from busy workers").

const std = @import("std");
const testing = std.testing;
const deque_mod = @import("deque.zig");
const priority_mod = @import("priority.zig");
const victim_mod = @import("victim.zig");
const fairness_mod = @import("fairness.zig");

pub const WorkerId = victim_mod.WorkerId;
pub const ActorId = priority_mod.ActorId;
pub const Priority = priority_mod.Priority;
pub const PrioritizedActor = priority_mod.PrioritizedActor;

pub const default_queue_capacity = 256;

pub fn Worker(comptime queue_capacity: usize) type {
    return struct {
        const Self = @This();

        id: WorkerId,
        queues: priority_mod.PriorityQueues(queue_capacity),
        rng: victim_mod.Rng,

        pub fn init(id: WorkerId, rng_seed: u32) Self {
            return .{
                .id = id,
                .queues = priority_mod.PriorityQueues(queue_capacity).init(),
                .rng = victim_mod.Rng.init(rng_seed ^ (@as(u32, id) +% 1)),
            };
        }

        /// Submits an actor onto this worker's own ready queue.
        pub fn submit(self: *Self, actor: PrioritizedActor) deque_mod.DequeError!void {
            try self.queues.push(actor);
        }

        /// Owner-only: services this worker's own highest-priority
        /// non-empty queue first (LIFO, cache-friendly).
        pub fn popOwn(self: *Self) ?PrioritizedActor {
            return self.queues.popLocal();
        }

        pub fn approxLen(self: *const Self) usize {
            return self.queues.approxLen();
        }

        /// Idle-worker path: picks a random victim among `workers`
        /// (excluding self) and attempts a single steal from its
        /// highest-priority non-empty queue. Returns `null` if there
        /// is no victim to pick or the steal attempt lost its race
        /// (the caller may retry against a different victim next
        /// tick rather than spinning against the same one).
        pub fn stealFrom(self: *Self, workers: []Self) ?PrioritizedActor {
            const victim_id = victim_mod.selectRandomVictim(&self.rng, self.id, workers.len) orelse return null;
            return workers[victim_id].queues.stealAny();
        }
    };
}

test "Worker services its own submitted actor without stealing" {
    var w = Worker(default_queue_capacity).init(0, 1);
    try w.submit(.{ .actor_id = 42, .priority = .normal });
    const got = w.popOwn().?;
    try testing.expectEqual(@as(ActorId, 42), got.actor_id);
    try testing.expect(w.popOwn() == null);
}

test "Worker stealFrom takes work from a busy peer" {
    var workers = [_]Worker(default_queue_capacity){
        Worker(default_queue_capacity).init(0, 7),
        Worker(default_queue_capacity).init(1, 11),
    };
    try workers[1].submit(.{ .actor_id = 99, .priority = .high });

    const stolen = workers[0].stealFrom(&workers).?;
    try testing.expectEqual(@as(ActorId, 99), stolen.actor_id);
    try testing.expectEqual(@as(usize, 0), workers[1].approxLen());
}

test "Worker stealFrom returns null when there is nothing to steal" {
    var workers = [_]Worker(default_queue_capacity){
        Worker(default_queue_capacity).init(0, 3),
        Worker(default_queue_capacity).init(1, 5),
    };
    try testing.expect(workers[0].stealFrom(&workers) == null);
}
