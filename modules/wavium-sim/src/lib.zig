const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-sim";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-sim", moduleName());
}
