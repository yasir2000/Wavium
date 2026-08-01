//! Thin re-export facade for the "drivers" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-hal/src/driver.zig (probe/attach/detach lifecycle),
//! re-exported here via modules/wavium-hal/src/lib.zig; this file exists
//! only so callers can reach it from the top-level layout without
//! duplicating any logic.
const std = @import("std");

pub const drivers = @import("wavium-hal");

test "drivers facade re-exports modules/wavium-hal driver lifecycle" {
    try std.testing.expectEqual(drivers.DriverState.probed, drivers.DriverState.probed);
    var manager = drivers.DriverManager.init();
    try std.testing.expect(manager.getAttached(1) == null);
}
