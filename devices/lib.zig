//! Thin re-export facade for the "devices" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-hal/src/{device_kind,discovery}.zig (device inventory and
//! discovery), re-exported here via modules/wavium-hal/src/lib.zig; this
//! file exists only so callers can reach it from the top-level layout
//! without duplicating any logic.
const std = @import("std");

pub const devices = @import("wavium-hal");

test "devices facade re-exports modules/wavium-hal device discovery" {
    try std.testing.expectEqual(devices.DeviceKind.cpu, devices.DeviceKind.cpu);
    var inventory = devices.DeviceInventory.init();
    try inventory.add(.{ .id = 1, .kind = .cpu, .base_address = 0x1000, .irq = null, .discovered_via = .static_table });
    try std.testing.expectEqual(@as(usize, 1), inventory.countByKind(.cpu));
}
