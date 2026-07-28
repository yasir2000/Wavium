const std = @import("std");

pub const MessageHeader = struct {
    msg_type: u16,
    source: u64,
    destination: u64,
    priority: u8,
};

pub const Message = struct {
    header: MessageHeader,
    payload: []const u8,
};

pub const frame_header_size: usize = 2 + 8 + 8 + 1 + 4;

pub const BackpressurePolicy = enum {
    drop_new,
    reject_new,
};

pub const EnqueueResult = enum {
    enqueued,
    dropped,
};

pub const BoundedMessageQueue = struct {
    allocator: std.mem.Allocator,
    capacity: usize,
    policy: BackpressurePolicy,
    queue: std.ArrayListUnmanaged(OwnedMessage),

    const OwnedMessage = struct {
        header: MessageHeader,
        payload: []u8,
    };

    pub fn init(allocator: std.mem.Allocator, capacity: usize, policy: BackpressurePolicy) BoundedMessageQueue {
        return .{
            .allocator = allocator,
            .capacity = capacity,
            .policy = policy,
            .queue = .empty,
        };
    }

    pub fn deinit(self: *BoundedMessageQueue) void {
        for (self.queue.items) |m| self.allocator.free(m.payload);
        self.queue.deinit(self.allocator);
    }

    pub fn enqueue(self: *BoundedMessageQueue, msg: Message) !EnqueueResult {
        if (self.queue.items.len >= self.capacity) {
            return switch (self.policy) {
                .drop_new => .dropped,
                .reject_new => error.QueueFull,
            };
        }

        const payload = try self.allocator.dupe(u8, msg.payload);
        try self.queue.append(self.allocator, .{
            .header = msg.header,
            .payload = payload,
        });
        return .enqueued;
    }

    pub fn dequeue(self: *BoundedMessageQueue) ?Message {
        if (self.queue.items.len == 0) return null;
        const owned = self.queue.orderedRemove(0);
        return .{ .header = owned.header, .payload = owned.payload };
    }
};

pub fn encodeFrame(msg: Message, out: []u8) !usize {
    const total_size = frame_header_size + msg.payload.len;
    if (out.len < total_size) return error.BufferTooSmall;
    if (msg.payload.len > std.math.maxInt(u32)) return error.PayloadTooLarge;

    std.mem.writeInt(u16, out[0..2], msg.header.msg_type, .little);
    std.mem.writeInt(u64, out[2..10], msg.header.source, .little);
    std.mem.writeInt(u64, out[10..18], msg.header.destination, .little);
    out[18] = msg.header.priority;
    std.mem.writeInt(u32, out[19..23], @intCast(msg.payload.len), .little);
    @memcpy(out[23..total_size], msg.payload);
    return total_size;
}

pub fn decodeFrame(frame: []const u8) !Message {
    if (frame.len < frame_header_size) return error.InvalidFrame;
    const payload_len = std.mem.readInt(u32, frame[19..23], .little);
    const total_size = frame_header_size + payload_len;
    if (frame.len < total_size) return error.InvalidFrame;

    return .{
        .header = .{
            .msg_type = std.mem.readInt(u16, frame[0..2], .little),
            .source = std.mem.readInt(u64, frame[2..10], .little),
            .destination = std.mem.readInt(u64, frame[10..18], .little),
            .priority = frame[18],
        },
        .payload = frame[23..total_size],
    };
}

test "message header basic fields" {
    const msg = Message{
        .header = .{ .msg_type = 1, .source = 10, .destination = 11, .priority = 2 },
        .payload = "ok",
    };
    try std.testing.expectEqual(@as(u16, 1), msg.header.msg_type);
}

test "frame encode and decode roundtrip" {
    const msg = Message{
        .header = .{ .msg_type = 7, .source = 100, .destination = 200, .priority = 3 },
        .payload = "hello",
    };

    var buf: [128]u8 = undefined;
    const used = try encodeFrame(msg, buf[0..]);
    const decoded = try decodeFrame(buf[0..used]);

    try std.testing.expectEqual(@as(u16, 7), decoded.header.msg_type);
    try std.testing.expectEqual(@as(u64, 100), decoded.header.source);
    try std.testing.expectEqualStrings("hello", decoded.payload);
}

test "frame decode rejects short frame" {
    try std.testing.expectError(error.InvalidFrame, decodeFrame("bad"));
}

test "bounded queue drop policy" {
    var q = BoundedMessageQueue.init(std.testing.allocator, 2, .drop_new);
    defer q.deinit();

    const msg = Message{ .header = .{ .msg_type = 1, .source = 1, .destination = 2, .priority = 0 }, .payload = "x" };
    try std.testing.expectEqual(EnqueueResult.enqueued, try q.enqueue(msg));
    try std.testing.expectEqual(EnqueueResult.enqueued, try q.enqueue(msg));
    try std.testing.expectEqual(EnqueueResult.dropped, try q.enqueue(msg));
}

test "bounded queue reject policy" {
    var q = BoundedMessageQueue.init(std.testing.allocator, 1, .reject_new);
    defer q.deinit();

    const msg = Message{ .header = .{ .msg_type = 1, .source = 1, .destination = 2, .priority = 0 }, .payload = "x" };
    _ = try q.enqueue(msg);
    try std.testing.expectError(error.QueueFull, q.enqueue(msg));
}

test "bounded queue stress retains capacity bound" {
    var q = BoundedMessageQueue.init(std.testing.allocator, 64, .drop_new);
    defer q.deinit();

    const msg = Message{ .header = .{ .msg_type = 9, .source = 1, .destination = 2, .priority = 1 }, .payload = "payload" };
    var i: usize = 0;
    var dropped: usize = 0;

    while (i < 5000) : (i += 1) {
        const res = try q.enqueue(msg);
        if (res == .dropped) dropped += 1;
    }

    try std.testing.expect(dropped > 0);
    try std.testing.expect(q.queue.items.len <= 64);

    while (q.dequeue()) |m| {
        std.testing.allocator.free(m.payload);
    }
}
