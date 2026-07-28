const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-freestanding";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-freestanding", moduleName());
}
