//! Thin re-export facade for the "network" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-fabric/src/lib.zig (message framing and the bounded
//! backpressure queue used for inter-actor messaging); this file exists
//! only so callers can reach it from the top-level layout without
//! duplicating any logic.
const std = @import("std");

pub const network = @import("wavium-fabric");

test "network facade re-exports modules/wavium-fabric" {
    try std.testing.expectEqual(@as(usize, 2 + 8 + 8 + 1 + 4), network.frame_header_size);
}
