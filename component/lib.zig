//! Thin re-export facade for the "component" subsystem named in the
//! original Prompt 01 top-level repository layout. The real implementation
//! lives in modules/wavium-component/src/lib.zig (component loading,
//! world linking, and the WASM execution runtime); this file exists only
//! so callers can reach it from the top-level layout without duplicating
//! any logic.
const std = @import("std");

pub const component = @import("wavium-component");

test "component facade re-exports modules/wavium-component" {
    const meta = component.ComponentMetadata{ .id = 1, .name = "demo" };
    try std.testing.expectEqual(@as(component.ComponentId, 1), meta.id);
}
