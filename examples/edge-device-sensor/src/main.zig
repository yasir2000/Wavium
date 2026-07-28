const std = @import("std");

pub fn readSensor(id: u32) []const u8 {
    return switch (id) {
        0 => "temperature=21.5C",
        1 => "humidity=48%",
        else => "sensor unavailable",
    };
}

test "sensor read is stable" {
    try std.testing.expectEqualStrings("temperature=21.5C", readSensor(0));
}
