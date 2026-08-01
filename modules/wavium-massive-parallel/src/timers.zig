//! Distributed timers: each core owns its own bounded timer list, so
//! arming/expiring timers never requires cross-core synchronization
//! (no global timer thread or shared timer heap to contend on). A
//! `DistributedTimers` value is just an array of independent
//! per-core wheels; a core only ever touches its own index.

pub const TimerId = u32;
pub const Deadline = u64;

pub const TimerError = error{
    WheelFull,
    TimerNotFound,
};

fn PerCoreTimerWheel(comptime capacity: usize) type {
    return struct {
        ids: [capacity]TimerId = undefined,
        deadlines: [capacity]Deadline = undefined,
        occupied: [capacity]bool = undefined,
        count: usize = 0,

        const Self = @This();

        pub fn init() Self {
            var self: Self = .{ .ids = undefined, .deadlines = undefined, .occupied = undefined, .count = 0 };
            for (&self.occupied) |*o| o.* = false;
            return self;
        }

        pub fn arm(self: *Self, id: TimerId, deadline: Deadline) TimerError!void {
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                if (!self.occupied[i]) {
                    self.ids[i] = id;
                    self.deadlines[i] = deadline;
                    self.occupied[i] = true;
                    self.count += 1;
                    return;
                }
            }
            return TimerError.WheelFull;
        }

        pub fn cancel(self: *Self, id: TimerId) TimerError!void {
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                if (self.occupied[i] and self.ids[i] == id) {
                    self.occupied[i] = false;
                    self.count -= 1;
                    return;
                }
            }
            return TimerError.TimerNotFound;
        }

        /// Fills `out` with the ids of every timer whose deadline is
        /// `<= now`, removing them from the wheel, returning how many
        /// were written.
        pub fn popExpired(self: *Self, now: Deadline, out: []TimerId) usize {
            var written: usize = 0;
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                if (self.occupied[i] and self.deadlines[i] <= now) {
                    if (written < out.len) {
                        out[written] = self.ids[i];
                        written += 1;
                    }
                    self.occupied[i] = false;
                    self.count -= 1;
                }
            }
            return written;
        }
    };
}

/// One independent timer wheel per core, indexed by local core id -
/// no core ever reaches into another's wheel.
pub fn DistributedTimers(comptime max_cores: usize, comptime capacity_per_core: usize) type {
    const WheelT = PerCoreTimerWheel(capacity_per_core);
    return struct {
        wheels: [max_cores]WheelT = undefined,
        core_count: usize,

        const Self = @This();

        pub fn init(core_count: usize) Self {
            var self: Self = .{ .wheels = undefined, .core_count = core_count };
            for (&self.wheels) |*w| w.* = WheelT.init();
            return self;
        }

        pub fn arm(self: *Self, core_id: usize, id: TimerId, deadline: Deadline) TimerError!void {
            return self.wheels[core_id].arm(id, deadline);
        }

        pub fn cancel(self: *Self, core_id: usize, id: TimerId) TimerError!void {
            return self.wheels[core_id].cancel(id);
        }

        pub fn popExpired(self: *Self, core_id: usize, now: Deadline, out: []TimerId) usize {
            return self.wheels[core_id].popExpired(now, out);
        }
    };
}

const testing = @import("std").testing;

test "DistributedTimers arms and expires timers independently per core" {
    var timers = DistributedTimers(4, 8).init(4);
    try timers.arm(0, 1, 100);
    try timers.arm(1, 2, 50);

    var out: [4]TimerId = undefined;
    // Core 0's timer isn't due yet at now=60.
    try testing.expectEqual(@as(usize, 0), timers.popExpired(0, 60, &out));
    // Core 1's timer IS due at now=60.
    try testing.expectEqual(@as(usize, 1), timers.popExpired(1, 60, &out));
    try testing.expectEqual(@as(TimerId, 2), out[0]);
}

test "DistributedTimers cancel removes a timer before it expires" {
    var timers = DistributedTimers(2, 4).init(2);
    try timers.arm(0, 5, 1000);
    try timers.cancel(0, 5);
    try testing.expectError(TimerError.TimerNotFound, timers.cancel(0, 5));

    var out: [1]TimerId = undefined;
    try testing.expectEqual(@as(usize, 0), timers.popExpired(0, 1000, &out));
}
