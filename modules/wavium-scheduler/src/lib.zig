const std = @import("std");

pub const Scheduler = @import("scheduler.zig").Scheduler;
pub const Task = @import("scheduler.zig").Task;

fn increment(ptr: *anyopaque) void {
    const counter: *u32 = @ptrCast(@alignCast(ptr));
    counter.* += 1;
}

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
