//! Thin re-export facade for the "scheduler" subsystem named in the
//! original Prompt 01 top-level repository layout. The real implementation
//! lives in modules/wavium-scheduler/src/lib.zig (priority-based
//! cooperative scheduler); this file exists only so callers can reach it
//! from the top-level layout without duplicating any logic.
const std = @import("std");

pub const scheduler = @import("wavium-scheduler");

test "scheduler facade re-exports modules/wavium-scheduler" {
    try std.testing.expectEqual(@as(usize, 4), scheduler.PRIORITY_LEVELS);
    try std.testing.expectEqual(scheduler.Priority.realtime, scheduler.Priority.realtime);
}
