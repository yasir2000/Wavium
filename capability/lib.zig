//! Thin re-export facade for the "capability" subsystem named in the
//! original Prompt 01 top-level repository layout. The real implementation
//! lives in modules/wavium-security/src/capability.zig (capability tokens,
//! permission sets, issue/authorize/derive/revoke); this file exists only
//! so callers can reach it from the top-level layout without duplicating
//! any logic.
const std = @import("std");

pub const capability = @import("wavium-security");

test "capability facade re-exports modules/wavium-security capability API" {
    var perms = capability.PermissionSet.empty;
    perms.insert(.storage_read);

    const token = capability.issue(1, perms);
    try std.testing.expect(capability.authorize(token, .storage_read));
    try std.testing.expect(!capability.authorize(token, .storage_write));
}
