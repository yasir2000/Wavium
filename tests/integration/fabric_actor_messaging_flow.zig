const std = @import("std");
const fabric = @import("wavium-fabric");
const actor = @import("wavium-actor");

test "fabric frame to actor mailbox flow" {
    var mailbox = actor.Mailbox.init(std.testing.allocator);
    defer mailbox.deinit();

    const msg = fabric.Message{
        .header = .{ .msg_type = 2, .source = 1, .destination = 99, .priority = 5 },
        .payload = "ping",
    };

    var frame_buf: [128]u8 = undefined;
    const used = try fabric.encodeFrame(msg, frame_buf[0..]);
    const decoded = try fabric.decodeFrame(frame_buf[0..used]);

    try mailbox.enqueue(decoded.payload);
    const queued = mailbox.dequeue().?;
    defer std.testing.allocator.free(queued);

    try std.testing.expectEqual(@as(u16, 2), decoded.header.msg_type);
    try std.testing.expectEqualStrings("ping", queued);
}
