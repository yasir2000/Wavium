const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-debug";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-debug", moduleName());
}
