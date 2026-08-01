//! Remote-free queue: a bounded, lock-free multi-producer/single-consumer
//! queue (Vyukov-style, per-cell sequence numbers) used to let *other*
//! cores return blocks that they did not allocate back to the owning
//! core without ever taking a lock or touching the owner's hot free
//! lists directly. Only the owning core ever pops from this queue
//! (during `reclaimRemote`), which is what keeps the owner's local
//! alloc/free fast path 100% contention-free: remote frees only ever
//! push here, they never race the owner for the underlying `Slab`.
//!
//! This module intentionally reimplements the Vyukov MPSC pattern
//! locally (rather than importing `wavium-lockfree`) to keep this
//! module family decoupled, matching this repository's established
//! convention of independent, self-contained `wavium-*` modules.

const std = @import("std");
const testing = std.testing;

pub const RemoteFreeError = error{QueueFull};

pub fn RemoteFreeQueue(comptime T: type, comptime capacity: usize) type {
    comptime {
        if (capacity == 0 or (capacity & (capacity - 1)) != 0) {
            @compileError("RemoteFreeQueue capacity must be a power of two");
        }
    }

    return struct {
        const Self = @This();

        const Cell = struct {
            sequence: std.atomic.Value(usize),
            value: T,
        };

        cells: [capacity]Cell,
        enqueue_pos: std.atomic.Value(usize),
        dequeue_pos: std.atomic.Value(usize),

        pub fn init() Self {
            var self: Self = .{
                .cells = undefined,
                .enqueue_pos = std.atomic.Value(usize).init(0),
                .dequeue_pos = std.atomic.Value(usize).init(0),
            };
            for (&self.cells, 0..) |*cell, i| {
                cell.* = .{ .sequence = std.atomic.Value(usize).init(i), .value = undefined };
            }
            return self;
        }

        /// Called by any core (owner or remote) to push a free request.
        /// Lock-free: contends only with other pushers via a CAS loop
        /// on `enqueue_pos`, never with the single consumer.
        pub fn push(self: *Self, value: T) RemoteFreeError!void {
            var pos = self.enqueue_pos.load(.monotonic);
            while (true) {
                const cell = &self.cells[pos % capacity];
                const seq = cell.sequence.load(.acquire);
                const diff = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos));
                if (diff == 0) {
                    if (self.enqueue_pos.cmpxchgWeak(pos, pos + 1, .monotonic, .monotonic)) |actual| {
                        pos = actual;
                    } else {
                        cell.value = value;
                        cell.sequence.store(pos + 1, .release);
                        return;
                    }
                } else if (diff < 0) {
                    return RemoteFreeError.QueueFull;
                } else {
                    pos = self.enqueue_pos.load(.monotonic);
                }
            }
        }

        /// Called only by the owning core to drain queued remote
        /// frees. Not thread-safe with respect to other consumers -
        /// by design there is only ever one.
        pub fn pop(self: *Self) ?T {
            var pos = self.dequeue_pos.load(.monotonic);
            while (true) {
                const cell = &self.cells[pos % capacity];
                const seq = cell.sequence.load(.acquire);
                const diff = @as(isize, @intCast(seq)) - @as(isize, @intCast(pos + 1));
                if (diff == 0) {
                    if (self.dequeue_pos.cmpxchgWeak(pos, pos + 1, .monotonic, .monotonic)) |actual| {
                        pos = actual;
                    } else {
                        const value = cell.value;
                        cell.sequence.store(pos + capacity, .release);
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

test "RemoteFreeQueue delivers values in FIFO order" {
    var q = RemoteFreeQueue(u32, 4).init();
    try q.push(10);
    try q.push(20);
    try testing.expectEqual(@as(u32, 10), q.pop().?);
    try testing.expectEqual(@as(u32, 20), q.pop().?);
    try testing.expect(q.pop() == null);
}

test "RemoteFreeQueue reports QueueFull at capacity" {
    var q = RemoteFreeQueue(u32, 2).init();
    try q.push(1);
    try q.push(2);
    try testing.expectError(RemoteFreeError.QueueFull, q.push(3));
}
