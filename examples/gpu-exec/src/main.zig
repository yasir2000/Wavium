const std = @import("std");

pub fn dispatch(command: []const u8) u32 {
    return @intCast(command.len);
}

test "dispatch reports payload size" {
    try std.testing.expectEqual(@as(u32, 7), dispatch("compute"));
}
