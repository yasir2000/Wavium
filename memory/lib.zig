//! Thin re-export facade for the "memory" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-memory/src/lib.zig (physical frame allocator, arenas,
//! quotas); this file exists only so callers can reach it from the
//! top-level layout without duplicating any logic.
const std = @import("std");

pub const memory = @import("wavium-memory");

test "memory facade re-exports modules/wavium-memory" {
    try std.testing.expect(memory.PAGE_SIZE > 0);
}
