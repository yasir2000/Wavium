const std = @import("std");

pub const TaskId = u32;
pub const ActorId = u32;
pub const CoreId = u16;

pub const Task = struct {
    id: TaskId,
};

pub const TimerEntry = struct {
    deadline_ticks: u64,
    actor_id: ActorId,
};

pub const SchedulerError = error{
    QueueFull,
};

pub const ready_capacity: usize = 64;
pub const actor_capacity: usize = 64;
pub const timer_capacity: usize = 32;

/// Bounded ready queue owned by a single core. `len` is tracked with an
/// atomic counter so cross-core work-stealing logic (see steal.zig) can
/// read queue depth without a lock. Full lock-free MPMC ring-buffer
/// semantics for the push/pop boundary itself are built out in the
/// dedicated lock-free-runtime-infrastructure milestone.
pub const ReadyQueue = struct {
    tasks: [ready_capacity]Task,
    head: usize,
    tail: usize,
    len: std.atomic.Value(usize),

    pub fn init() ReadyQueue {
        return .{ .tasks = undefined, .head = 0, .tail = 0, .len = std.atomic.Value(usize).init(0) };
    }

    pub fn push(self: *ReadyQueue, task: Task) SchedulerError!void {
        if (self.len.load(.acquire) >= ready_capacity) return error.QueueFull;
        self.tasks[self.tail] = task;
        self.tail = (self.tail + 1) % ready_capacity;
        _ = self.len.fetchAdd(1, .release);
    }

    pub fn pop(self: *ReadyQueue) ?Task {
        if (self.len.load(.acquire) == 0) return null;
        const t = self.tasks[self.head];
        self.head = (self.head + 1) % ready_capacity;
        _ = self.len.fetchSub(1, .release);
        return t;
    }

    pub fn count(self: *ReadyQueue) usize {
        return self.len.load(.acquire);
    }
};

pub const ActorQueue = struct {
    actors: [actor_capacity]ActorId,
    head: usize,
    tail: usize,
    len: usize,

    pub fn init() ActorQueue {
        return .{ .actors = undefined, .head = 0, .tail = 0, .len = 0 };
    }

    pub fn push(self: *ActorQueue, id: ActorId) SchedulerError!void {
        if (self.len >= actor_capacity) return error.QueueFull;
        self.actors[self.tail] = id;
        self.tail = (self.tail + 1) % actor_capacity;
        self.len += 1;
    }

    pub fn pop(self: *ActorQueue) ?ActorId {
        if (self.len == 0) return null;
        const a = self.actors[self.head];
        self.head = (self.head + 1) % actor_capacity;
        self.len -= 1;
        return a;
    }

    /// Removes the first occurrence of `id`, preserving relative order of
    /// the remaining entries. Used by actor migration.
    pub fn remove(self: *ActorQueue, id: ActorId) bool {
        var i: usize = 0;
        var found: ?usize = null;
        while (i < self.len) : (i += 1) {
            const idx = (self.head + i) % actor_capacity;
            if (self.actors[idx] == id) {
                found = i;
                break;
            }
        }
        const fi = found orelse return false;

        var j = fi;
        while (j + 1 < self.len) : (j += 1) {
            const from_idx = (self.head + j + 1) % actor_capacity;
            const to_idx = (self.head + j) % actor_capacity;
            self.actors[to_idx] = self.actors[from_idx];
        }
        self.len -= 1;
        self.tail = (self.head + self.len) % actor_capacity;
        return true;
    }

    pub fn count(self: *ActorQueue) usize {
        return self.len;
    }
};

pub const TimerQueue = struct {
    timers: [timer_capacity]TimerEntry,
    len: usize,

    pub fn init() TimerQueue {
        return .{ .timers = undefined, .len = 0 };
    }

    pub fn schedule(self: *TimerQueue, entry: TimerEntry) SchedulerError!void {
        if (self.len >= timer_capacity) return error.QueueFull;

        var i = self.len;
        while (i > 0 and self.timers[i - 1].deadline_ticks > entry.deadline_ticks) : (i -= 1) {
            self.timers[i] = self.timers[i - 1];
        }
        self.timers[i] = entry;
        self.len += 1;
    }

    /// Removes and returns every timer whose deadline has passed, in
    /// ascending deadline order, up to `out.len` entries.
    pub fn popExpired(self: *TimerQueue, now_ticks: u64, out: []TimerEntry) usize {
        var n: usize = 0;
        while (self.len > 0 and self.timers[0].deadline_ticks <= now_ticks and n < out.len) {
            out[n] = self.timers[0];
            n += 1;

            var j: usize = 0;
            while (j + 1 < self.len) : (j += 1) {
                self.timers[j] = self.timers[j + 1];
            }
            self.len -= 1;
        }
        return n;
    }

    pub fn count(self: *TimerQueue) usize {
        return self.len;
    }
};

/// One independent scheduler per CPU core: its own ready queue (runnable
/// tasks), actor queue (actors with pending mailbox work), and timer queue
/// (deadline-ordered wakeups). No cross-core locks are taken by normal
/// submit/pop operations; only work stealing and migration touch another
/// core's scheduler.
pub const CoreScheduler = struct {
    core_id: CoreId,
    numa_node: u8,
    ready: ReadyQueue,
    actors: ActorQueue,
    timers: TimerQueue,

    pub fn init(core_id: CoreId, numa_node: u8) CoreScheduler {
        return .{
            .core_id = core_id,
            .numa_node = numa_node,
            .ready = ReadyQueue.init(),
            .actors = ActorQueue.init(),
            .timers = TimerQueue.init(),
        };
    }

    pub fn submitTask(self: *CoreScheduler, task: Task) SchedulerError!void {
        return self.ready.push(task);
    }

    pub fn submitActor(self: *CoreScheduler, id: ActorId) SchedulerError!void {
        return self.actors.push(id);
    }

    pub fn scheduleTimer(self: *CoreScheduler, entry: TimerEntry) SchedulerError!void {
        return self.timers.schedule(entry);
    }

    pub fn popReady(self: *CoreScheduler) ?Task {
        return self.ready.pop();
    }

    pub fn tickTimers(self: *CoreScheduler, now_ticks: u64, out: []TimerEntry) usize {
        return self.timers.popExpired(now_ticks, out);
    }

    pub fn readyLen(self: *CoreScheduler) usize {
        return self.ready.count();
    }
};

test "ReadyQueue push/pop preserves FIFO order and tracks count" {
    var q = ReadyQueue.init();
    try q.push(.{ .id = 1 });
    try q.push(.{ .id = 2 });
    try std.testing.expectEqual(@as(usize, 2), q.count());

    try std.testing.expectEqual(@as(TaskId, 1), q.pop().?.id);
    try std.testing.expectEqual(@as(TaskId, 2), q.pop().?.id);
    try std.testing.expect(q.pop() == null);
}

test "ReadyQueue rejects push past capacity" {
    var q = ReadyQueue.init();
    var i: usize = 0;
    while (i < ready_capacity) : (i += 1) try q.push(.{ .id = @intCast(i) });
    try std.testing.expectError(error.QueueFull, q.push(.{ .id = 999 }));
}

test "ActorQueue remove preserves order of remaining actors" {
    var q = ActorQueue.init();
    try q.push(10);
    try q.push(20);
    try q.push(30);

    try std.testing.expect(q.remove(20));
    try std.testing.expectEqual(@as(usize, 2), q.count());
    try std.testing.expectEqual(@as(ActorId, 10), q.pop().?);
    try std.testing.expectEqual(@as(ActorId, 30), q.pop().?);
    try std.testing.expect(!q.remove(999));
}

test "TimerQueue pops expired entries in deadline order" {
    var q = TimerQueue.init();
    try q.schedule(.{ .deadline_ticks = 30, .actor_id = 3 });
    try q.schedule(.{ .deadline_ticks = 10, .actor_id = 1 });
    try q.schedule(.{ .deadline_ticks = 20, .actor_id = 2 });

    var out: [4]TimerEntry = undefined;
    const n = q.popExpired(25, out[0..]);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(@as(ActorId, 1), out[0].actor_id);
    try std.testing.expectEqual(@as(ActorId, 2), out[1].actor_id);
    try std.testing.expectEqual(@as(usize, 1), q.count());
}

test "CoreScheduler ties ready/actor/timer queues to a core+numa identity" {
    var sched = CoreScheduler.init(0, 1);
    try sched.submitTask(.{ .id = 42 });
    try sched.submitActor(7);
    try sched.scheduleTimer(.{ .deadline_ticks = 5, .actor_id = 7 });

    try std.testing.expectEqual(@as(usize, 1), sched.readyLen());
    try std.testing.expectEqual(@as(TaskId, 42), sched.popReady().?.id);

    var out: [2]TimerEntry = undefined;
    try std.testing.expectEqual(@as(usize, 1), sched.tickTimers(10, out[0..]));
}
