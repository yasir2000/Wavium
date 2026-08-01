const std = @import("std");

pub const Scheduler = @import("scheduler.zig").Scheduler;
pub const Task = @import("scheduler.zig").Task;
pub const Priority = @import("scheduler.zig").Priority;
pub const PRIORITY_LEVELS = @import("scheduler.zig").PRIORITY_LEVELS;

fn increment(ptr: *anyopaque) void {
    const counter: *u32 = @ptrCast(@alignCast(ptr));
    counter.* += 1;
}

fn recordOrder(ptr: *anyopaque) void {
    const t: *TaggedTask = @ptrCast(@alignCast(ptr));
    t.result[t.count.*] = t.tag;
    t.count.* += 1;
}

const TaggedTask = struct {
    result: *[8]u8,
    count: *usize,
    tag: u8,
};

test "cooperative scheduler executes submitted tasks" {
    var sched = Scheduler.init(std.testing.allocator);
    defer sched.deinit();

    var count: u32 = 0;
    try sched.submit(.{ .ctx = @ptrCast(&count), .run = increment });
    try sched.submit(.{ .ctx = @ptrCast(&count), .run = increment });

    const executed = sched.runUntilEmpty();
    try std.testing.expectEqual(@as(usize, 2), executed);
    try std.testing.expectEqual(@as(u32, 2), count);
}

test "higher priority tasks always run before lower priority ones" {
    var sched = Scheduler.init(std.testing.allocator);
    defer sched.deinit();

    var result: [8]u8 = undefined;
    var count: usize = 0;

    var low_task = TaggedTask{ .result = &result, .count = &count, .tag = 'L' };
    var normal_task = TaggedTask{ .result = &result, .count = &count, .tag = 'N' };
    var high_task = TaggedTask{ .result = &result, .count = &count, .tag = 'H' };
    var realtime_task = TaggedTask{ .result = &result, .count = &count, .tag = 'R' };

    // Submitted lowest-priority first to prove submission order doesn't matter.
    try sched.submit(.{ .ctx = @ptrCast(&low_task), .run = recordOrder, .priority = .low });
    try sched.submit(.{ .ctx = @ptrCast(&normal_task), .run = recordOrder, .priority = .normal });
    try sched.submit(.{ .ctx = @ptrCast(&high_task), .run = recordOrder, .priority = .high });
    try sched.submit(.{ .ctx = @ptrCast(&realtime_task), .run = recordOrder, .priority = .realtime });

    try std.testing.expectEqual(@as(usize, 4), sched.pendingCount());
    const executed = sched.runUntilEmpty();
    try std.testing.expectEqual(@as(usize, 4), executed);
    try std.testing.expectEqualSlices(u8, "RHNL", result[0..4]);
}

test "default task priority is normal" {
    const task = Task{ .ctx = undefined, .run = increment };
    try std.testing.expectEqual(Priority.normal, task.priority);
}
