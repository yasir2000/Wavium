//! Distributed queues: one bounded FIFO task queue per core. A core
//! only ever pushes/pops its OWN queue directly (no synchronization
//! needed for that fast path); cross-core work redistribution is an
//! explicit, occasional `steal` operation rather than a queue that
//! every core contends on.

pub const QueueError = error{
    QueueFull,
    QueueEmpty,
    NothingToSteal,
};

fn PerCoreQueue(comptime T: type, comptime capacity: usize) type {
    return struct {
        items: [capacity]T = undefined,
        head: usize = 0,
        len: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return .{ .items = undefined, .head = 0, .len = 0 };
        }

        pub fn push(self: *Self, value: T) QueueError!void {
            if (self.len == capacity) return QueueError.QueueFull;
            const tail = (self.head + self.len) % capacity;
            self.items[tail] = value;
            self.len += 1;
        }

        pub fn pop(self: *Self) QueueError!T {
            if (self.len == 0) return QueueError.QueueEmpty;
            const value = self.items[self.head];
            self.head = (self.head + 1) % capacity;
            self.len -= 1;
            return value;
        }

        pub fn count(self: *const Self) usize {
            return self.len;
        }
    };
}

/// One independent bounded queue per core.
pub fn DistributedQueues(comptime T: type, comptime max_cores: usize, comptime capacity: usize) type {
    const QueueT = PerCoreQueue(T, capacity);
    return struct {
        queues: [max_cores]QueueT = undefined,
        core_count: usize,

        const Self = @This();

        pub fn init(core_count: usize) Self {
            var self: Self = .{ .queues = undefined, .core_count = core_count };
            for (&self.queues) |*q| q.* = QueueT.init();
            return self;
        }

        pub fn push(self: *Self, core_id: usize, value: T) QueueError!void {
            return self.queues[core_id].push(value);
        }

        pub fn pop(self: *Self, core_id: usize) QueueError!T {
            return self.queues[core_id].pop();
        }

        pub fn count(self: *const Self, core_id: usize) usize {
            return self.queues[core_id].count();
        }

        /// Moves roughly half of `from_core`'s queued items onto
        /// `to_core`'s queue (an explicit, occasional rebalancing
        /// step - not a per-operation synchronization cost). Returns
        /// how many items moved.
        pub fn steal(self: *Self, from_core: usize, to_core: usize) QueueError!usize {
            const available = self.queues[from_core].count();
            if (available == 0) return QueueError.NothingToSteal;
            const to_move = (available + 1) / 2;
            var moved: usize = 0;
            while (moved < to_move) : (moved += 1) {
                const value = self.queues[from_core].pop() catch break;
                self.queues[to_core].push(value) catch {
                    // Target full: put it back and stop stealing.
                    self.queues[from_core].push(value) catch {};
                    break;
                };
            }
            return moved;
        }
    };
}

const testing = @import("std").testing;

test "DistributedQueues push/pop is FIFO per core" {
    var queues = DistributedQueues(u32, 4, 8).init(4);
    try queues.push(0, 1);
    try queues.push(0, 2);
    try testing.expectEqual(@as(u32, 1), try queues.pop(0));
    try testing.expectEqual(@as(u32, 2), try queues.pop(0));
    try testing.expectError(QueueError.QueueEmpty, queues.pop(0));
}

test "DistributedQueues steal moves half of a busy core's items" {
    var queues = DistributedQueues(u32, 2, 8).init(2);
    try queues.push(0, 10);
    try queues.push(0, 20);
    try queues.push(0, 30);
    try queues.push(0, 40);

    const moved = try queues.steal(0, 1);
    try testing.expectEqual(@as(usize, 2), moved);
    try testing.expectEqual(@as(usize, 2), queues.count(0));
    try testing.expectEqual(@as(usize, 2), queues.count(1));
}

test "DistributedQueues steal from an empty core fails" {
    var queues = DistributedQueues(u32, 2, 4).init(2);
    try testing.expectError(QueueError.NothingToSteal, queues.steal(0, 1));
}
