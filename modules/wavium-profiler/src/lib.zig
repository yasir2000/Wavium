const std = @import("std");

pub fn moduleName() []const u8 {
    return "wavium-profiler";
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-profiler", moduleName());
}
