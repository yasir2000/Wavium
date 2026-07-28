const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-ci";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-ci", moduleName());
}
