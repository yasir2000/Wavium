//! Fairness / starvation prevention: an actor that has been waiting in
//! a low-priority queue for too long is promoted to the next priority
//! class up, guaranteeing it eventually reaches `high` and gets
//! serviced - bounding worst-case wait time regardless of how much
//! high-priority work keeps arriving.

const std = @import("std");
const testing = std.testing;
const priority_mod = @import("priority.zig");

pub const Priority = priority_mod.Priority;
pub const ActorId = priority_mod.ActorId;

/// Ticks a waiting actor has been observed for before it is promoted
/// one priority class. Chosen small enough that starvation is bounded
/// in the presence of continuous high-priority arrivals, without
/// promoting so aggressively that priority stops meaning anything.
pub const promotion_threshold: u32 = 8;

pub const AgingEntry = struct {
    actor_id: ActorId,
    priority: Priority,
    wait_ticks: u32,
};

/// Advances one scheduling tick for a waiting actor and returns the
/// (possibly promoted) entry. Promotion resets `wait_ticks` so the
/// actor must again wait `promotion_threshold` ticks at its new,
/// higher class before promoting further.
pub fn tick(entry: AgingEntry) AgingEntry {
    var next = entry;
    next.wait_ticks += 1;
    if (next.wait_ticks >= promotion_threshold and next.priority != .high) {
        next.priority = switch (next.priority) {
            .low => .normal,
            .normal => .high,
            .high => .high,
        };
        next.wait_ticks = 0;
    }
    return next;
}

/// Round-robin fairness helper: rotates a starting index each call so
/// consecutive scheduling rounds don't always favor the same worker
/// when iterating over a fixed set (e.g. when broadcasting steal
/// attempts across all workers rather than a single random victim).
pub const RoundRobin = struct {
    next_index: usize,
    count: usize,

    pub fn init(count: usize) RoundRobin {
        return .{ .next_index = 0, .count = count };
    }

    pub fn advance(self: *RoundRobin) usize {
        const idx = self.next_index;
        self.next_index = (self.next_index + 1) % self.count;
        return idx;
    }
};

test "tick promotes a low-priority actor after the threshold is reached" {
    var entry = AgingEntry{ .actor_id = 1, .priority = .low, .wait_ticks = 0 };
    var i: u32 = 0;
    while (i < promotion_threshold) : (i += 1) entry = tick(entry);
    try testing.expectEqual(Priority.normal, entry.priority);
    try testing.expectEqual(@as(u32, 0), entry.wait_ticks);
}

test "tick eventually promotes all the way to high priority" {
    var entry = AgingEntry{ .actor_id = 1, .priority = .low, .wait_ticks = 0 };
    var rounds: u32 = 0;
    while (entry.priority != .high and rounds < 100) : (rounds += 1) {
        entry = tick(entry);
    }
    try testing.expectEqual(Priority.high, entry.priority);
}

test "tick leaves high-priority actors unchanged" {
    var entry = AgingEntry{ .actor_id = 1, .priority = .high, .wait_ticks = 0 };
    var i: u32 = 0;
    while (i < promotion_threshold * 2) : (i += 1) entry = tick(entry);
    try testing.expectEqual(Priority.high, entry.priority);
}

test "RoundRobin cycles through indices fairly" {
    var rr = RoundRobin.init(3);
    try testing.expectEqual(@as(usize, 0), rr.advance());
    try testing.expectEqual(@as(usize, 1), rr.advance());
    try testing.expectEqual(@as(usize, 2), rr.advance());
    try testing.expectEqual(@as(usize, 0), rr.advance());
}
