const std = @import("std");

pub const version = "0.1.0";

pub fn sdkName() []const u8 {
    return "wavium-zig-sdk";
}

pub fn packageName() []const u8 {
    return "wavium";
}

test "sdk name" {
    try std.testing.expectEqualStrings("wavium-zig-sdk", sdkName());
}
