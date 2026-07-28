const std = @import("std");

pub fn supervise(event: []const u8) []const u8 {
    if (std.mem.eql(u8, event, "restart")) {
        return "actor restarted";
    }
    return "actor observed event";
}

test "supervision handles restart" {
    try std.testing.expectEqualStrings("actor restarted", supervise("restart"));
}
