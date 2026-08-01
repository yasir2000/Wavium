const std = @import("std");
const cs = @import("core_scheduler.zig");

pub const StealError = error{NothingToSteal};

/// Steals up to half of `victim`'s ready queue into `thief`'s ready queue,
/// returning the number of tasks moved. This models cross-core work
/// stealing; the ready queue's own atomic length counter (see
/// core_scheduler.ReadyQueue) means the depth check here never observes a
/// torn read even though push/pop on the victim's own core may be
/// happening concurrently.
pub fn stealHalf(victim: *cs.CoreScheduler, thief: *cs.CoreScheduler) StealError!usize {
    const available = victim.readyLen();
    if (available == 0) return error.NothingToSteal;

    const to_steal = if (available == 1) 1 else available / 2;
    var moved: usize = 0;
    while (moved < to_steal) : (moved += 1) {
        const task = victim.popReady() orelse break;
        thief.submitTask(task) catch break;
    }
    return moved;
}

test "stealHalf moves half of the victim's ready queue" {
    var victim = cs.CoreScheduler.init(0, 0);
    var thief = cs.CoreScheduler.init(1, 0);

    var i: usize = 0;
    while (i < 10) : (i += 1) try victim.submitTask(.{ .id = @intCast(i) });

    const moved = try stealHalf(&victim, &thief);
    try std.testing.expectEqual(@as(usize, 5), moved);
    try std.testing.expectEqual(@as(usize, 5), victim.readyLen());
    try std.testing.expectEqual(@as(usize, 5), thief.readyLen());
}

test "stealHalf steals the single task when only one is available" {
    var victim = cs.CoreScheduler.init(0, 0);
    var thief = cs.CoreScheduler.init(1, 0);
    try victim.submitTask(.{ .id = 1 });

    const moved = try stealHalf(&victim, &thief);
    try std.testing.expectEqual(@as(usize, 1), moved);
    try std.testing.expectEqual(@as(usize, 0), victim.readyLen());
}

test "stealHalf returns NothingToSteal when victim is empty" {
    var victim = cs.CoreScheduler.init(0, 0);
    var thief = cs.CoreScheduler.init(1, 0);
    try std.testing.expectError(error.NothingToSteal, stealHalf(&victim, &thief));
}
