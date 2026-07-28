const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-toolchain";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-toolchain", moduleName());
}
