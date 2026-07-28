const std = @import("std");

pub const CapabilityToken = @import("capability.zig").CapabilityToken;
pub const Permission = @import("capability.zig").Permission;
pub const PermissionSet = @import("capability.zig").PermissionSet;
pub const ResourceHandle = @import("capability.zig").ResourceHandle;
pub const CapabilityManager = @import("capability.zig").CapabilityManager;
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
    var token = mgr.issue(9, perms);

    try std.testing.expect(authorize(token, .storage_read));
    try mgr.revoke(&token);
    try std.testing.expect(mgr.isRevoked(token));
    try std.testing.expect(!authorize(token, .storage_read));
}
