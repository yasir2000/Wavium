const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-devkit";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-devkit", moduleName());
}
