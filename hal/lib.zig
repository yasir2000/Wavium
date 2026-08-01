//! Thin re-export facade for the "hal" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-hal/src/lib.zig (the umbrella hardware abstraction layer
//! covering discovery, init dispatch, and driver lifecycle); this file
//! exists only so callers can reach it from the top-level layout without
//! duplicating any logic.
const std = @import("std");

pub const hal = @import("wavium-hal");

test "hal facade re-exports modules/wavium-hal" {
    try std.testing.expectEqual(hal.DeviceKind.cpu, hal.DeviceKind.cpu);
    var registry = hal.DriverRegistry.init();
    _ = &registry;
}
