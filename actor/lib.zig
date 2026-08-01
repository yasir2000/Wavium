//! Thin re-export facade for the "actor" subsystem named in the original
//! Prompt 01 top-level repository layout. The real implementation lives in
//! modules/wavium-actor/src/lib.zig (mailbox queue, actor refs, supervision
//! strategies); this file exists only so callers can reach it from the
//! top-level layout without duplicating any logic.
const std = @import("std");

pub const actor = @import("wavium-actor");

test "actor facade re-exports modules/wavium-actor" {
    const ref = actor.ActorRef{ .id = 99, .status = .active };
    try std.testing.expectEqual(actor.ActorStatus.active, ref.status);
}
