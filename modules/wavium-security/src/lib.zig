const std = @import("std");

pub const CapabilityToken = @import("capability.zig").CapabilityToken;
pub const Permission = @import("capability.zig").Permission;
pub const PermissionSet = @import("capability.zig").PermissionSet;
pub const ResourceHandle = @import("capability.zig").ResourceHandle;
pub const CapabilityManager = @import("capability.zig").CapabilityManager;
pub const CapabilityError = @import("capability.zig").CapabilityError;
pub const issue = @import("capability.zig").issue;
pub const authorize = @import("capability.zig").authorize;
pub const authorizeResource = @import("capability.zig").authorizeResource;

test "capability authorization honors permission set" {
    var perms = PermissionSet.empty;
    perms.insert(.storage_read);

    const token = issue(7, perms);
    try std.testing.expect(authorize(token, .storage_read));
    try std.testing.expect(!authorize(token, .storage_write));
}

test "resource handle authorization checks subject and permission" {
    var perms = PermissionSet.empty;
    perms.insert(.storage_read);
    const token = issue(42, perms);

    const ok = ResourceHandle{
        .resource_id = 1,
        .owner_subject_id = 42,
        .required_permission = .storage_read,
    };
    const wrong_subject = ResourceHandle{
        .resource_id = 1,
        .owner_subject_id = 43,
        .required_permission = .storage_read,
    };

    try std.testing.expect(authorizeResource(token, ok));
    try std.testing.expect(!authorizeResource(token, wrong_subject));
}

test "capability manager revocation denies authorization" {
    var mgr = CapabilityManager.init(std.testing.allocator);
    defer mgr.deinit();

    var perms = PermissionSet.empty;
    perms.insert(.storage_read);
    var token = try mgr.issue(9, perms);

    try std.testing.expect(authorize(token, .storage_read));
    try mgr.revoke(&token);
    try std.testing.expect(mgr.isRevoked(token));
    try std.testing.expect(!authorize(token, .storage_read));
}

test "capability manager derive attenuates permissions and inherits revocation" {
    var mgr = CapabilityManager.init(std.testing.allocator);
    defer mgr.deinit();

    var parent_perms = PermissionSet.empty;
    parent_perms.insert(.storage_read);
    parent_perms.insert(.storage_write);
    var parent = try mgr.issue(1, parent_perms);

    var child_perms = PermissionSet.empty;
    child_perms.insert(.storage_read);
    const child = try mgr.derive(parent, 2, child_perms);

    try std.testing.expect(authorize(child, .storage_read));
    try std.testing.expect(!authorize(child, .storage_write));

    // Escalation beyond the parent's permission set is rejected.
    var escalated_perms = PermissionSet.empty;
    escalated_perms.insert(.gpu_execute);
    try std.testing.expectError(error.PermissionEscalation, mgr.derive(parent, 2, escalated_perms));

    // Revoking the parent cascades to the derived child.
    try mgr.revoke(&parent);
    try std.testing.expect(mgr.isRevoked(child));
    try std.testing.expectError(error.ParentRevoked, mgr.derive(parent, 3, child_perms));
}
