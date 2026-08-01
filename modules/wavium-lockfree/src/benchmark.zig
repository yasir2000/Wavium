const std = @import("std");
const mpmc_mod = @import("mpmc_queue.zig");

/// Baseline comparator: a bounded queue guarded by a naive spinlock (busy
/// loop on an atomic bool), representing the "mutex-protected" approach
/// the lock-free structures in this module are benchmarked against. There
/// are no OS threads in this freestanding runtime, so contention itself
/// isn't reproduced here - the benchmark instead measures single-threaded
/// push/pop overhead, which still highlights the CAS-retry-loop cost of
/// the lock-free path versus the lock/unlock cost of the spinlock path.
pub fn SpinlockQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();

        buffer: [capacity]T,
        head: usize,
        tail: usize,
        len: usize,
        locked: std.atomic.Value(bool),

        pub fn init() Self {
            return .{
                .buffer = undefined,
                .head = 0,
                .tail = 0,
                .len = 0,
                .locked = std.atomic.Value(bool).init(false),
            };
        }

        fn lock(self: *Self) void {
            while (self.locked.cmpxchgWeak(false, true, .acquire, .monotonic) != null) {
                std.atomic.spinLoopHint();
            }
        }

        fn unlock(self: *Self) void {
            self.locked.store(false, .release);
        }

        pub fn push(self: *Self, value: T) bool {
            self.lock();
            defer self.unlock();
            if (self.len >= capacity) return false;
            self.buffer[self.tail] = value;
            self.tail = (self.tail + 1) % capacity;
            self.len += 1;
            return true;
        }

        pub fn pop(self: *Self) ?T {
            self.lock();
            defer self.unlock();
            if (self.len == 0) return null;
            const value = self.buffer[self.head];
            self.head = (self.head + 1) % capacity;
            self.len -= 1;
            return value;
        }
    };
}

pub const BenchmarkResult = struct {
    lockfree_ns: u64,
    spinlock_ns: u64,
    iterations: usize,
};

/// Runs `iterations` push+pop cycles through both an `MpmcQueue` and a
/// `SpinlockQueue` of matching capacity and reports elapsed wall-clock
/// time for each. This is a single-threaded micro-benchmark (no real
/// contention), so it should be read as "CAS-retry overhead" vs
/// "lock/unlock overhead" rather than a true concurrent throughput
/// comparison.
pub fn compareQueues(comptime capacity: usize, iterations: usize) BenchmarkResult {
    var lockfree_q = mpmc_mod.MpmcQueue(u32, capacity).init();
    var spinlock_q = SpinlockQueue(u32, capacity).init();

    var timer = std.time.Timer.start() catch unreachable;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = lockfree_q.push(@intCast(i % capacity));
        _ = lockfree_q.pop();
    }
    const lockfree_ns = timer.lap();

    i = 0;
    while (i < iterations) : (i += 1) {
        _ = spinlock_q.push(@intCast(i % capacity));
        _ = spinlock_q.pop();
    }
    const spinlock_ns = timer.lap();

    return .{ .lockfree_ns = lockfree_ns, .spinlock_ns = spinlock_ns, .iterations = iterations };
}

test "SpinlockQueue behaves like a normal bounded FIFO queue" {
    var q = SpinlockQueue(u32, 2).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(!q.push(3));
    try std.testing.expectEqual(@as(u32, 1), q.pop().?);
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expect(q.pop() == null);
}

test "compareQueues runs both implementations and reports non-zero iteration counts" {
    const result = compareQueues(16, 1000);
    try std.testing.expectEqual(@as(usize, 1000), result.iterations);
    // Wall-clock timings are environment-dependent; only assert the
    // benchmark actually executed rather than asserting a specific
    // winner, to avoid flaky tests on slow/loaded CI machines.
}
