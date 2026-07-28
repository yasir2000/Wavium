const std = @import("std");

pub const TaskFn = *const fn (*anyopaque) void;

pub const Task = struct {
    ctx: *anyopaque,
    run: TaskFn,
};

pub const Scheduler = struct {
    allocator: std.mem.Allocator,
    queue: std.ArrayListUnmanaged(Task),

    pub fn init(allocator: std.mem.Allocator) Scheduler {
        return .{
            .allocator = allocator,
            .queue = .empty,
        };
    }

    pub fn deinit(self: *Scheduler) void {
        self.queue.deinit(self.allocator);
    }

    pub fn submit(self: *Scheduler, task: Task) !void {
        try self.queue.append(self.allocator, task);
    }

    pub fn runOne(self: *Scheduler) bool {
        if (self.queue.items.len == 0) return false;
        const task = self.queue.orderedRemove(0);
        task.run(task.ctx);
        return true;
    }

    pub fn runUntilEmpty(self: *Scheduler) usize {
        var executed: usize = 0;
        while (self.runOne()) {
            executed += 1;
        }
        return executed;
    }
};
