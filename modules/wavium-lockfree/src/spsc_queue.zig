const std = @import("std");
const base = @import("ring_buffer.zig");

/// Wait-free bounded queue for exactly one producer and one consumer.
/// `head` (next pop index) is written only by the consumer; `tail` (next
/// push index) is written only by the producer. Each is padded to its own
/// cache line to prevent false sharing between the producer's and
/// consumer's cores.
pub fn SpscQueue(comptime T: type, comptime capacity: usize) type {
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("SpscQueue capacity must be a power of two");
        }
    }
    return struct {
        const Self = @This();
        const mask = capacity - 1;

        buffer: [capacity]T,
        head: std.atomic.Value(usize) align(base.cache_line_bytes),
        tail: std.atomic.Value(usize) align(base.cache_line_bytes),

        pub fn init() Self {
            return .{
                .buffer = undefined,
                .head = std.atomic.Value(usize).init(0),
                .tail = std.atomic.Value(usize).init(0),
            };
        }

        /// Must only ever be called by the single producer.
        pub fn push(self: *Self, value: T) bool {
            const tail = self.tail.load(.monotonic);
            const head = self.head.load(.acquire);
            if (tail -% head >= capacity) return false;
            self.buffer[tail & mask] = value;
            self.tail.store(tail +% 1, .release);
            return true;
        }

        /// Must only ever be called by the single consumer.
        pub fn pop(self: *Self) ?T {
            const head = self.head.load(.monotonic);
            const tail = self.tail.load(.acquire);
            if (head == tail) return null;
            const value = self.buffer[head & mask];
            self.head.store(head +% 1, .release);
            return value;
        }

        pub fn isEmpty(self: *Self) bool {
            return self.head.load(.acquire) == self.tail.load(.acquire);
        }
    };
}

test "SpscQueue preserves FIFO order for a single producer/consumer" {
    var q = SpscQueue(u32, 4).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expectEqual(@as(u32, 1), q.pop().?);
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expect(q.pop() == null);
}

test "SpscQueue rejects push once full" {
    var q = SpscQueue(u32, 2).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(!q.push(3));
}

test "SpscQueue reports empty correctly across push/pop cycles" {
    var q = SpscQueue(u32, 2).init();
    try std.testing.expect(q.isEmpty());
    try std.testing.expect(q.push(1));
    try std.testing.expect(!q.isEmpty());
    _ = q.pop();
    try std.testing.expect(q.isEmpty());
}
