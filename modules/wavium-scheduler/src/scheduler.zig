const std = @import("std");

pub const TaskFn = *const fn (*anyopaque) void;

/// Scheduling priority. Higher-priority queues are always drained before
/// lower-priority ones (strict priority scheduling), matching the
/// "high-priority tasks preempt the run queue" requirement for the
/// runtime scheduler.
pub const Priority = enum(u2) {
    low = 0,
    normal = 1,
    high = 2,
    realtime = 3,
};

pub const PRIORITY_LEVELS: usize = 4;

pub const Task = struct {
    ctx: *anyopaque,
    run: TaskFn,
    priority: Priority = .normal,
};

pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    queues: [PRIORITY_LEVELS]std.ArrayListUnmanaged(Task),

    pub fn init(allocator: std.mem.Allocator) Scheduler {
        return .{
            .allocator = allocator,
            .queues = .{ .empty, .empty, .empty, .empty },
        };
    }

    pub fn deinit(self: *Scheduler) void {
        for (&self.queues) |*queue| {
            queue.deinit(self.allocator);
        }
    }

    pub fn submit(self: *Scheduler, task: Task) !void {
        const level = @intFromEnum(task.priority);
        try self.queues[level].append(self.allocator, task);
    }

    pub fn pendingCount(self: Scheduler) usize {
        var total: usize = 0;
        for (self.queues) |queue| total += queue.items.len;
        return total;
    }

    /// Runs the single highest-priority pending task (FIFO within the same
    /// priority level). A `realtime` task always runs before any `high`,
    /// `normal`, or `low` task regardless of submission order.
    pub fn runOne(self: *Scheduler) bool {
        var level: usize = PRIORITY_LEVELS;
        while (level > 0) {
            level -= 1;
            if (self.queues[level].items.len == 0) continue;
            const task = self.queues[level].orderedRemove(0);
            task.run(task.ctx);
            return true;
        }
        return false;
    }

    pub fn runUntilEmpty(self: *Scheduler) usize {
        var executed: usize = 0;
        while (self.runOne()) {
            executed += 1;
        }
        return executed;
    }
};
