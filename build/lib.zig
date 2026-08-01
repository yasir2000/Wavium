//! Thin re-export facade for the "build" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-build/src/lib.zig (component build/package/manifest
//! pipeline); this file exists only so callers can reach it from the
//! top-level layout without duplicating any logic.
const std = @import("std");

pub const wavium_build = @import("wavium-build");

test "build facade re-exports modules/wavium-build" {
    try std.testing.expectEqual(wavium_build.BuildTarget.wasm32_component, wavium_build.BuildTarget.wasm32_component);
    try std.testing.expectEqual(@as(u16, 1), wavium_build.current_schema_version);
}
