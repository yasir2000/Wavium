//! Thin re-export facade for the "wit" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-wit/src/lib.zig (WIT world/interface parsing and
//! canonical ABI codecs); this file exists only so callers can reach it
//! from the top-level layout without duplicating any logic.
const std = @import("std");

pub const wit = @import("wavium-wit");

test "wit facade re-exports modules/wavium-wit" {
    try std.testing.expectEqual(wit.CanonicalAbiType.i32, wit.canonicalAbiType("u32"));
}
