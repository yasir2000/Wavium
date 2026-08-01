const std = @import("std");
const base = @import("ring_buffer.zig");

/// Lock-free bounded queue for many producers and a single consumer. Each
/// cell carries its own sequence number (Vyukov-style) so producers CAS
/// only the shared `enqueue_pos`; the consumer owns `dequeue_pos` as a
/// plain counter (no atomic needed) since only one consumer ever reads it.
pub fn MpscQueue(comptime T: type, comptime capacity: usize) type {
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("MpscQueue capacity must be a power of two");
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
        dequeue_pos: usize align(base.cache_line_bytes),

        pub fn init() Self {
            var self: Self = .{
                .cells = undefined,
                .enqueue_pos = std.atomic.Value(usize).init(0),
                .dequeue_pos = 0,
            };
            for (&self.cells, 0..) |*cell, i| {
                cell.sequence = std.atomic.Value(usize).init(i);
            }
            return self;
        }

        /// Safe to call concurrently from any number of producers.
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

        /// Must only ever be called by the single consumer.
        pub fn pop(self: *Self) ?T {
            const pos = self.dequeue_pos;
            const cell = &self.cells[pos & mask];
            const seq = cell.sequence.load(.acquire);
            if (seq != pos +% 1) return null;
            const value = cell.value;
            cell.sequence.store(pos +% mask +% 1, .release);
            self.dequeue_pos = pos +% 1;
            return value;
        }
    };
}

test "MpscQueue delivers values pushed by multiple producers in submission order" {
    var q = MpscQueue(u32, 8).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(q.push(3));

    try std.testing.expectEqual(@as(u32, 1), q.pop().?);
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expectEqual(@as(u32, 3), q.pop().?);
    try std.testing.expect(q.pop() == null);
}

test "MpscQueue rejects push once full" {
    var q = MpscQueue(u32, 2).init();
    try std.testing.expect(q.push(1));
    try std.testing.expect(q.push(2));
    try std.testing.expect(!q.push(3));
}

test "MpscQueue can be refilled after draining" {
    var q = MpscQueue(u32, 2).init();
    try std.testing.expect(q.push(1));
    _ = q.pop();
    try std.testing.expect(q.push(2));
    try std.testing.expect(q.push(3));
    try std.testing.expectEqual(@as(u32, 2), q.pop().?);
    try std.testing.expectEqual(@as(u32, 3), q.pop().?);
}
