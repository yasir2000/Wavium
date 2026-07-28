const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-boot";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-boot", moduleName());
}
