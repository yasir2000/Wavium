const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-sandbox";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-sandbox", moduleName());
}
