//! Chase-Lev work-stealing deque: the owning worker pushes and pops
//! from the `bottom` end (LIFO, cache-friendly for its own recently
//! produced work), while any other worker may `steal` from the `top`
//! end (FIFO, taking the oldest work first so a thief rarely races the
//! owner for the same item). This is the classic Chase-Lev/Arora
//! algorithm, adapted to a fixed-capacity backing array (no resizing)
//! to match this repository's allocator-free module convention.

const std = @import("std");
const testing = std.testing;

pub const DequeError = error{Full};

pub fn ChaseLevDeque(comptime T: type, comptime capacity: usize) type {
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("ChaseLevDeque capacity must be a power of two");
        }
    }

    return struct {
        const Self = @This();

        buffer: [capacity]T,
        top: std.atomic.Value(usize),
        bottom: std.atomic.Value(usize),

        pub fn init() Self {
            return .{
                .buffer = undefined,
                .top = std.atomic.Value(usize).init(0),
                .bottom = std.atomic.Value(usize).init(0),
            };
        }

        /// Owner-only: pushes `item` onto the bottom of the deque.
        pub fn pushBottom(self: *Self, item: T) DequeError!void {
            const b = self.bottom.load(.monotonic);
            const t = self.top.load(.acquire);
            if (b - t >= capacity) return DequeError.Full;
            self.buffer[b % capacity] = item;
            self.bottom.store(b + 1, .release);
        }

        /// Owner-only: pops from the bottom (LIFO). Races with
        /// concurrent thieves only when exactly one item remains.
        pub fn popBottom(self: *Self) ?T {
            const b = self.bottom.load(.monotonic) -% 1;
            self.bottom.store(b, .monotonic);
            const t = self.top.load(.acquire);

            const size = @as(isize, @bitCast(b -% t));
            if (size < 0) {
                // Deque was already empty; restore bottom.
                self.bottom.store(t, .monotonic);
                return null;
            }

            const item = self.buffer[b % capacity];
            if (size == 0) {
                // Last element: race against thieves for it.
                if (self.top.cmpxchgStrong(t, t + 1, .acq_rel, .monotonic) != null) {
                    // A thief won the race first.
                    self.bottom.store(t + 1, .monotonic);
                    return null;
                }
                self.bottom.store(t + 1, .monotonic);
            }
            return item;
        }

        /// Any worker: attempts to steal from the top (FIFO, oldest
        /// item first). Returns `null` both when the deque is empty
        /// and when a race against the owner or another thief is lost
        /// (the caller should simply retry with a different victim).
        pub fn steal(self: *Self) ?T {
            const t = self.top.load(.acquire);
            const b = self.bottom.load(.acquire);

            const size = @as(isize, @bitCast(b -% t));
            if (size <= 0) return null;

            const item = self.buffer[t % capacity];
            if (self.top.cmpxchgStrong(t, t + 1, .acq_rel, .monotonic) != null) {
                // Lost the race - someone else already took this slot.
                return null;
            }
            return item;
        }

        /// Approximate size, useful for victim-selection heuristics.
        /// May be stale under concurrent access; never used for
        /// correctness, only for choosing a likely-busy victim.
        pub fn approxLen(self: *const Self) usize {
            const b = self.bottom.load(.monotonic);
            const t = self.top.load(.monotonic);
            if (b < t) return 0;
            return b - t;
        }
    };
}

test "ChaseLevDeque pushBottom/popBottom behaves as a LIFO stack for the owner" {
    var deque = ChaseLevDeque(u32, 4).init();
    try deque.pushBottom(1);
    try deque.pushBottom(2);
    try testing.expectEqual(@as(u32, 2), deque.popBottom().?);
    try testing.expectEqual(@as(u32, 1), deque.popBottom().?);
    try testing.expect(deque.popBottom() == null);
}

test "ChaseLevDeque steal takes from the top (FIFO), oldest first" {
    var deque = ChaseLevDeque(u32, 4).init();
    try deque.pushBottom(1);
    try deque.pushBottom(2);
    try deque.pushBottom(3);
    try testing.expectEqual(@as(u32, 1), deque.steal().?);
    try testing.expectEqual(@as(u32, 2), deque.steal().?);
    try testing.expectEqual(@as(u32, 3), deque.popBottom().?);
}

test "ChaseLevDeque reports Full at capacity" {
    var deque = ChaseLevDeque(u32, 2).init();
    try deque.pushBottom(1);
    try deque.pushBottom(2);
    try testing.expectError(DequeError.Full, deque.pushBottom(3));
}

test "ChaseLevDeque steal on an empty deque returns null" {
    var deque = ChaseLevDeque(u32, 4).init();
    try testing.expect(deque.steal() == null);
}
