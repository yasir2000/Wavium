//! Priority stealing: actors carry a `Priority`, and both local pop
//! and cross-worker steal always prefer the highest-priority non-empty
//! class first. Each worker keeps one `ChaseLevDeque` per priority
//! class rather than a single deque with per-item comparisons, so
//! ordering is free (queue selection order) rather than a sort.

const std = @import("std");
const testing = std.testing;
const deque_mod = @import("deque.zig");

pub const Priority = enum(u8) {
    low = 0,
    normal = 1,
    high = 2,
};

pub const priority_count = 3;

/// Highest-to-lowest iteration order, used by both local pop and
/// steal so a worker always prefers its own (or a victim's) most
/// important work first.
pub const priority_order = [_]Priority{ .high, .normal, .low };

pub const ActorId = u32;

pub const PrioritizedActor = struct {
    actor_id: ActorId,
    priority: Priority,
};

/// A worker's full set of priority-segregated deques.
pub fn PriorityQueues(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        queues: [priority_count]deque_mod.ChaseLevDeque(ActorId, capacity),

        pub fn init() Self {
            var self: Self = .{ .queues = undefined };
            for (&self.queues) |*q| q.* = deque_mod.ChaseLevDeque(ActorId, capacity).init();
            return self;
        }

        pub fn push(self: *Self, actor: PrioritizedActor) deque_mod.DequeError!void {
            try self.queues[@intFromEnum(actor.priority)].pushBottom(actor.actor_id);
        }

        /// Owner-only local pop: tries high, then normal, then low.
        pub fn popLocal(self: *Self) ?PrioritizedActor {
            inline for (priority_order) |p| {
                if (self.queues[@intFromEnum(p)].popBottom()) |id| {
                    return .{ .actor_id = id, .priority = p };
                }
            }
            return null;
        }

        /// Steal-side: tries high, then normal, then low, from this
        /// (victim) worker's queues.
        pub fn stealAny(self: *Self) ?PrioritizedActor {
            inline for (priority_order) |p| {
                if (self.queues[@intFromEnum(p)].steal()) |id| {
                    return .{ .actor_id = id, .priority = p };
                }
            }
            return null;
        }

        pub fn approxLen(self: *const Self) usize {
            var total: usize = 0;
            for (self.queues) |q| total += q.approxLen();
            return total;
        }
    };
}

test "PriorityQueues popLocal prefers high priority over normal and low" {
    var queues = PriorityQueues(8).init();
    try queues.push(.{ .actor_id = 1, .priority = .low });
    try queues.push(.{ .actor_id = 2, .priority = .high });
    try queues.push(.{ .actor_id = 3, .priority = .normal });

    const first = queues.popLocal().?;
    try testing.expectEqual(Priority.high, first.priority);
    try testing.expectEqual(@as(ActorId, 2), first.actor_id);
}

test "PriorityQueues stealAny prefers high priority from the victim" {
    var queues = PriorityQueues(8).init();
    try queues.push(.{ .actor_id = 10, .priority = .normal });
    try queues.push(.{ .actor_id = 20, .priority = .high });

    const stolen = queues.stealAny().?;
    try testing.expectEqual(Priority.high, stolen.priority);
    try testing.expectEqual(@as(ActorId, 20), stolen.actor_id);
}

test "PriorityQueues approxLen sums across all priority classes" {
    var queues = PriorityQueues(8).init();
    try queues.push(.{ .actor_id = 1, .priority = .low });
    try queues.push(.{ .actor_id = 2, .priority = .high });
    try testing.expectEqual(@as(usize, 2), queues.approxLen());
}
