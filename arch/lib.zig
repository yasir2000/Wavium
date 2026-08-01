//! Thin re-export facade for the "arch" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-arch/src/lib.zig; this file exists only so callers can
//! reach it from the top-level layout without duplicating any logic.
const std = @import("std");

pub const arch = @import("wavium-arch");

test "arch facade re-exports modules/wavium-arch" {
    _ = try arch.currentArch();
    try std.testing.expectEqual(arch.Arch.x86_64, arch.Arch.x86_64);
}
