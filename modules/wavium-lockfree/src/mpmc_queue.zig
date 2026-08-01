const std = @import("std");
const base = @import("ring_buffer.zig");

/// Lock-free bounded multi-producer/multi-consumer queue (Vyukov's
/// algorithm). Every cell carries its own sequence number so a push/pop
/// only needs to CAS the shared `enqueue_pos`/`dequeue_pos` counter, never
/// the cell itself, keeping contention limited to a single cache line per
/// side.
pub fn MpmcQueue(comptime T: type, comptime capacity: usize) type {
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("MpmcQueue capacity must be a power of two");
        }
    }
    return struct {
        const Self = @This();
        const mask = capacity - 1;

        const Cell = struct {
            sequence: std.atomic.Value(usize),
            value: T,
        };

        cells: [capacity]Cell,
        enqueue_pos: std.atomic.Value(usize) align(base.cache_line_bytes),
        dequeue_pos: std.atomic.Value(usize) align(base.cache_line_bytes),

        pub fn init() Self {
            var self: Self = .{
                .cells = undefined,
                .enqueue_pos = std.atomic.Value(usize).init(0),
                .dequeue_pos = std.atomic.Value(usize).init(0),
            };
            for (&self.cells, 0..) |*cell, i| {
                cell.sequence = std.atomic.Value(usize).init(i);
            }
            return self;
        }

        pub fn push(self: *Self, value: T) bool {
            var pos = self.enqueue_pos.load(.monotonic);
            while (true) {
                const cell = &self.cells[pos & mask];
                const seq = cell.sequence.load(.acquire);
                const diff = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos));
                if (diff == 0) {
                    if (self.enqueue_pos.cmpxchgWeak(pos, pos +% 1, .monotonic, .monotonic)) |actual| {
                        pos = actual;
                    } else {
                        cell.value = value;
                        cell.sequence.store(pos +% 1, .release);
                        return true;
                    }
                } else if (diff < 0) {
                    return false;
                } else {
                    pos = self.enqueue_pos.load(.monotonic);
                }
            }
        }

        pub fn pop(self: *Self) ?T {
            var pos = self.dequeue_pos.load(.monotonic);
            while (true) {
                const cell = &self.cells[pos & mask];
                const seq = cell.sequence.load(.acquire);
                const diff = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos +% 1));
                if (diff == 0) {
                    if (self.dequeue_pos.cmpxchgWeak(pos, pos +% 1, .monotonic, .monotonic)) |actual| {
                        pos = actual;
                    } else {
                        const value = cell.value;
                        cell.sequence.store(pos +% mask +% 1, .release);
                        return value;
                    }
                } else if (diff < 0) {
                    return null;
                } else {
                    pos = self.dequeue_pos.load(.monotonic);
                }
            }
        }
    };
}

test "MpmcQueue preserves FIFO order under single-threaded push/pop" {
    var q = MpmcQueue(u32, 8).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(q.push(3));
    try std.testing.expectEqual(@as(u32, 1), q.pop().?);
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expectEqual(@as(u32, 3), q.pop().?);
    try std.testing.expect(q.pop() == null);
}

test "MpmcQueue rejects push once full and allows refill after drain" {
    var q = MpmcQueue(u32, 2).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(!q.push(3));

    _ = q.pop();
    try std.testing.expect(q.push(3));
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expectEqual(@as(u32, 3), q.pop().?);
}

test "MpmcQueue interleaved push/pop from multiple simulated producers/consumers" {
    var q = MpmcQueue(u32, 4).init();
    try std.testing.expect(q.push(10));
    try std.testing.expectEqual(@as(u32, 10), q.pop().?);
    try std.testing.expect(q.push(20));
    try std.testing.expect(q.push(30));
    try std.testing.expectEqual(@as(u32, 20), q.pop().?);
    try std.testing.expect(q.push(40));
    try std.testing.expectEqual(@as(u32, 30), q.pop().?);
    try std.testing.expectEqual(@as(u32, 40), q.pop().?);
}
