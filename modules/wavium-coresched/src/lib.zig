const std = @import("std");

/// Per-core scheduler architecture: every CPU owns an independent scheduler
/// instance (ready queue / actor queue / timer queue / worker), with
/// cross-core work stealing, actor migration, CPU affinity, and a
/// NUMA-aware greedy load balancer. Avoids global locks - only the ready
/// queue's atomic length counter and the explicit steal/migrate boundary
/// touch another core's state.
pub fn moduleName() []const u8 {
    return "wavium-coresched";
}

pub const core_scheduler = @import("core_scheduler.zig");
pub const worker = @import("worker.zig");
pub const steal = @import("steal.zig");
pub const affinity = @import("affinity.zig");
pub const migration = @import("migration.zig");
pub const balancer = @import("balancer.zig");

test "moduleName" {
    try std.testing.expectEqualStrings("wavium-coresched", moduleName());
}

var integration_last_task: ?core_scheduler.TaskId = null;

fn recordTask(task: core_scheduler.Task) void {
    integration_last_task = task.id;
}

test "end-to-end: submit, run, steal, migrate, and rebalance across per-core schedulers" {
    var cpu0 = core_scheduler.CoreScheduler.init(0, 0);
    const cpu1 = core_scheduler.CoreScheduler.init(1, 0);

    // CPU0 gets a burst of tasks and one actor; CPU1 starts idle.
    var i: usize = 0;
    while (i < 6) : (i += 1) try cpu0.submitTask(.{ .id = @intCast(i) });
    try cpu0.submitActor(100);

    var worker0 = worker.Worker{ .scheduler = &cpu0, .run_fn = recordTask };
    try worker0.runOnce();
    try std.testing.expectEqual(@as(core_scheduler.TaskId, 0), integration_last_task.?);
    try std.testing.expectEqual(@as(usize, 5), cpu0.readyLen());

    // Load balancer notices the imbalance and steals from CPU0 into CPU1.
    var cores = [_]core_scheduler.CoreScheduler{ cpu0, cpu1 };
    const moved = try balancer.rebalance(cores[0..]);
    try std.testing.expect(moved > 0);
    try std.testing.expect(cores[1].readyLen() > 0);

    // Migrate the actor from CPU0 to CPU1 (unrestricted affinity).
    try migration.migrateActor(&cores[0], &cores[1], 100, affinity.TaskAffinity.anyCore());
    try std.testing.expect(!cores[0].actors.remove(100));

    // A pinned actor cannot be migrated to a disallowed core.
    try cores[0].submitActor(200);
    const pinned = affinity.TaskAffinity.pinnedTo(0);
    try std.testing.expectError(error.TargetNotAllowed, migration.migrateActor(&cores[0], &cores[1], 200, pinned));
}
