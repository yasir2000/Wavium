const std = @import("std");

/// Cache line size assumed for false-sharing prevention across this module:
/// hot atomic indices/counters that are written by different cores are
/// aligned to this boundary so they never share a cache line.
pub const cache_line_bytes = 64;

/// Plain (non-atomic) fixed-capacity circular buffer. This is the raw
/// storage primitive the atomic SPSC/MPSC/MPMC queues are built around;
/// used on its own it requires external synchronization (e.g. a single
/// owner, or a caller-held lock) - see spsc_queue.zig/mpsc_queue.zig/
/// mpmc_queue.zig for the lock-free variants.
pub fn RingBuffer(comptime T: type, comptime capacity: usize) type {
    comptime {
        if (capacity == 0) @compileError("RingBuffer capacity must be > 0");
    }
    return struct {
        const Self = @This();

        buffer: [capacity]T,
        head: usize,
        tail: usize,
        len: usize,

        pub fn init() Self {
            return .{ .buffer = undefined, .head = 0, .tail = 0, .len = 0 };
        }

        /// Writes as many of `items` as fit; returns the number written.
        pub fn write(self: *Self, items: []const T) usize {
            var n: usize = 0;
            while (n < items.len and self.len < capacity) : (n += 1) {
                self.buffer[self.tail] = items[n];
                self.tail = (self.tail + 1) % capacity;
                self.len += 1;
            }
            return n;
        }

        /// Reads up to `out.len` items; returns the number read.
        pub fn read(self: *Self, out: []T) usize {
            var n: usize = 0;
            while (n < out.len and self.len > 0) : (n += 1) {
                out[n] = self.buffer[self.head];
                self.head = (self.head + 1) % capacity;
                self.len -= 1;
            }
            return n;
        }

        pub fn count(self: Self) usize {
            return self.len;
        }

        pub fn isFull(self: Self) bool {
            return self.len == capacity;
        }
    };
}

test "RingBuffer writes and reads back in FIFO order" {
    var rb = RingBuffer(u32, 4).init();
    const in = [_]u32{ 1, 2, 3 };
    try std.testing.expectEqual(@as(usize, 3), rb.write(in[0..]));

    var out: [2]u32 = undefined;
    try std.testing.expectEqual(@as(usize, 2), rb.read(out[0..]));
    try std.testing.expectEqual(@as(u32, 1), out[0]);
    try std.testing.expectEqual(@as(u32, 2), out[1]);
    try std.testing.expectEqual(@as(usize, 1), rb.count());
}

test "RingBuffer stops writing once full" {
    var rb = RingBuffer(u32, 2).init();
    const in = [_]u32{ 1, 2, 3 };
    try std.testing.expectEqual(@as(usize, 2), rb.write(in[0..]));
    try std.testing.expect(rb.isFull());
    try std.testing.expectEqual(@as(usize, 0), rb.write(in[0..1]));
}
