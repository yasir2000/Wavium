//! Thin re-export facade for the "security" subsystem named in the
//! original Prompt 01 top-level repository layout. The real implementation
//! lives in modules/wavium-security/src/lib.zig (capability tokens,
//! permission sets, and the attenuation/revocation-aware
//! CapabilityManager); this file exists only so callers can reach it from
//! the top-level layout without duplicating any logic.
const std = @import("std");

pub const security = @import("wavium-security");

test "security facade re-exports modules/wavium-security" {
    var perms = security.PermissionSet.empty;
    perms.insert(.storage_read);

    const token = security.issue(1, perms);
    try std.testing.expect(security.authorize(token, .storage_read));
}
