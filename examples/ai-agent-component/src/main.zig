const std = @import("std");

pub fn step(input: []const u8) []const u8 {
    if (std.mem.eql(u8, input, "plan")) return "plan -> execute -> verify";
    return "component observed input";
}

test "agent step produces workflow hint" {
    try std.testing.expectEqualStrings("plan -> execute -> verify", step("plan"));
}
