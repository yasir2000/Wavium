const std = @import("std");

pub const DeviceKind = enum {
    cpu,
    memory,
    storage,
    gpu,
    network,
};

test "device kind enum" {
    try std.testing.expectEqual(DeviceKind.cpu, DeviceKind.cpu);
}
