const std = @import("std");

pub const ActorStatus = enum {
    inactive,
    active,
    suspended,
};

pub const ActorRef = struct {
    id: u64,
    status: ActorStatus,
};

pub const Mailbox = struct {
    allocator: std.mem.Allocator,
    queue: std.ArrayListUnmanaged([]u8),

    pub fn init(allocator: std.mem.Allocator) Mailbox {
        return .{ .allocator = allocator, .queue = .empty };
    }

    pub fn deinit(self: *Mailbox) void {
        for (self.queue.items) |item| self.allocator.free(item);
        self.queue.deinit(self.allocator);
    }

    pub fn enqueue(self: *Mailbox, payload: []const u8) !void {
        const owned = try self.allocator.dupe(u8, payload);
        try self.queue.append(self.allocator, owned);
    }

    pub fn dequeue(self: *Mailbox) ?[]u8 {
        if (self.queue.items.len == 0) return null;
        return self.queue.orderedRemove(0);
    }
};

test "actor ref status" {
    const a = ActorRef{ .id = 99, .status = .active };
    try std.testing.expectEqual(ActorStatus.active, a.status);
}

test "mailbox enqueue and dequeue" {
    var mb = Mailbox.init(std.testing.allocator);
    defer mb.deinit();

    try mb.enqueue("hello");
    try mb.enqueue("world");

    const first = mb.dequeue().?;
    defer std.testing.allocator.free(first);
    const second = mb.dequeue().?;
    defer std.testing.allocator.free(second);

    try std.testing.expectEqualStrings("hello", first);
    try std.testing.expectEqualStrings("world", second);
    try std.testing.expect(mb.dequeue() == null);
}
