//! Thin re-export facade for the "storage" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-state/src/lib.zig (the append-only actor state log with
//! snapshot serialize/replay); this file exists only so callers can reach
//! it from the top-level layout without duplicating any logic.
const std = @import("std");

pub const storage = @import("wavium-state");

test "storage facade re-exports modules/wavium-state" {
    var log = storage.StateLog.init(std.testing.allocator);
    defer log.deinit();
    try std.testing.expectEqual(@as(usize, 0), log.entries.items.len);
}
