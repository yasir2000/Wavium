const std = @import("std");

pub fn echo(payload: []const u8, out: []u8) !usize {
    if (out.len < payload.len) return error.BufferTooSmall;
    @memcpy(out[0..payload.len], payload);
    return payload.len;
}

test "echo returns the input bytes" {
    var out: [16]u8 = undefined;
    const used = try echo("ping", out[0..]);
    try std.testing.expectEqual(@as(usize, 4), used);
    try std.testing.expectEqualStrings("ping", out[0..used]);
}
