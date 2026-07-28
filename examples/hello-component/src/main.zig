const std = @import("std");

pub fn greet() []const u8 {
    return "hello from wavium";
}

test "greet returns a stable message" {
    try std.testing.expectEqualStrings("hello from wavium", greet());
}
