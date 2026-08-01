//! Thin re-export facade for the "filesystem" subsystem named in the
//! original Prompt 01 top-level repository layout. The real implementation
//! lives in modules/wavium-wasi/src/lib.zig (capability-gated storage and
//! environment access); this file exists only so callers can reach it
//! from the top-level layout without duplicating any logic.
const std = @import("std");

pub const filesystem = @import("wavium-wasi");

test "filesystem facade re-exports modules/wavium-wasi storage API" {
    var ctx = filesystem.WasiContext.init(1);
    try std.testing.expect(ctx.environmentGet("PATH") == null);
}
