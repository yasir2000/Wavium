const std = @import("std");
const cs = @import("core_scheduler.zig");

pub const WorkerError = error{NoWork};

/// Decoupling seam: the worker never knows how to execute a task itself; it
/// only pops one from its owning core's ready queue and hands it to a bound
/// `TaskFn` (mirrors the ExecutionBackend/DriverLifecycle pattern used
/// elsewhere in this codebase).
pub const TaskFn = *const fn (task: cs.Task) void;

/// A single worker bound to exactly one core's scheduler - "CPU0 Worker",
/// "CPU1 Worker", etc. in the per-core architecture.
pub const Worker = struct {
    scheduler: *cs.CoreScheduler,
    run_fn: TaskFn,
    executed: usize = 0,

    pub fn runOnce(self: *Worker) WorkerError!void {
        const task = self.scheduler.popReady() orelse return error.NoWork;
        self.run_fn(task);
        self.executed += 1;
    }

    /// Runs until the local ready queue is empty, returning how many tasks
    /// were executed.
    pub fn drain(self: *Worker) usize {
        var n: usize = 0;
        while (true) {
            self.runOnce() catch break;
            n += 1;
        }
        return n;
    }
};

var test_last_task_id: ?cs.TaskId = null;

fn fakeRun(task: cs.Task) void {
    test_last_task_id = task.id;
}

test "Worker.runOnce executes exactly one task from its core" {
    var sched = cs.CoreScheduler.init(0, 0);
    try sched.submitTask(.{ .id = 5 });
    var worker = Worker{ .scheduler = &sched, .run_fn = fakeRun };

    test_last_task_id = null;
    try worker.runOnce();
    try std.testing.expectEqual(@as(cs.TaskId, 5), test_last_task_id.?);
    try std.testing.expectEqual(@as(usize, 1), worker.executed);

    try std.testing.expectError(error.NoWork, worker.runOnce());
}

test "Worker.drain executes every ready task" {
    var sched = cs.CoreScheduler.init(1, 0);
    try sched.submitTask(.{ .id = 1 });
    try sched.submitTask(.{ .id = 2 });
    try sched.submitTask(.{ .id = 3 });
    var worker = Worker{ .scheduler = &sched, .run_fn = fakeRun };

    const n = worker.drain();
    try std.testing.expectEqual(@as(usize, 3), n);
    try std.testing.expectEqual(@as(usize, 0), sched.readyLen());
}
