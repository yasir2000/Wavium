//! Thin re-export facade for the "packages" subsystem named in the
//! original Prompt 01 top-level repository layout. The real implementation
//! lives in modules/wavium-build/src/lib.zig (the .wvm manifest/package
//! schema and packageArtifact/verifyManifest/verifyPackage APIs); this
//! file exists only so callers can reach it from the top-level layout
//! without duplicating any logic.
const std = @import("std");

pub const packages = @import("wavium-build");

test "packages facade re-exports modules/wavium-build packaging API" {
    try std.testing.expectEqual(@as(u16, 1), packages.current_schema_version);
}
