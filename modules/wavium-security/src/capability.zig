const std = @import("std");

pub const Permission = enum(u8) {
    storage_read,
    storage_write,
    event_publish,
    gpu_execute,
    component_migrate,
};

pub const PermissionSet = std.EnumSet(Permission);

pub const CapabilityToken = struct {
    token_id: u64,
    subject_id: u64,
    permissions: PermissionSet,
    revoked: bool,
};

pub const ResourceHandle = struct {
    resource_id: u64,
    owner_subject_id: u64,
    required_permission: Permission,
};

pub const CapabilityError = error{
    PermissionEscalation,
    ParentRevoked,
    UnknownParent,
};

const IssuedTokenRecord = struct {
    permissions: PermissionSet,
    parent_token_id: ?u64,
};

pub const CapabilityManager = struct {
    allocator: std.mem.Allocator,
    next_token_id: u64,
    revoked_tokens: std.AutoHashMap(u64, void),
    issued: std.AutoHashMap(u64, IssuedTokenRecord),

    pub fn init(allocator: std.mem.Allocator) CapabilityManager {
        return .{
            .allocator = allocator,
            .next_token_id = 1,
            .revoked_tokens = std.AutoHashMap(u64, void).init(allocator),
            .issued = std.AutoHashMap(u64, IssuedTokenRecord).init(allocator),
        };
    }

    pub fn deinit(self: *CapabilityManager) void {
        self.revoked_tokens.deinit();
        self.issued.deinit();
    }

    pub fn issue(self: *CapabilityManager, subject_id: u64, permissions: PermissionSet) !CapabilityToken {
        const token = CapabilityToken{
            .token_id = self.next_token_id,
            .subject_id = subject_id,
            .permissions = permissions,
            .revoked = false,
        };
        try self.issued.put(token.token_id, .{ .permissions = permissions, .parent_token_id = null });
        self.next_token_id += 1;
        return token;
    }

    /// Derives a narrower (never broader) capability from `parent`,
    /// attributing it to `subject_id`. This is the attenuation operation
    /// central to capability-based security (ADR-003): a subject can only
    /// grant a subset of the permissions it already holds, and the derived
    /// token remains tied to its parent's revocation status.
    pub fn derive(self: *CapabilityManager, parent: CapabilityToken, subject_id: u64, permissions: PermissionSet) !CapabilityToken {
        if (self.isRevoked(parent)) {
            return error.ParentRevoked;
        }
        if (!self.issued.contains(parent.token_id)) {
            return error.UnknownParent;
        }
        if (!parent.permissions.supersetOf(permissions)) {
            return error.PermissionEscalation;
        }

        const token = CapabilityToken{
            .token_id = self.next_token_id,
            .subject_id = subject_id,
            .permissions = permissions,
            .revoked = false,
        };
        try self.issued.put(token.token_id, .{ .permissions = permissions, .parent_token_id = parent.token_id });
        self.next_token_id += 1;
        return token;
    }

    pub fn revoke(self: *CapabilityManager, token: *CapabilityToken) !void {
        token.revoked = true;
        try self.revoked_tokens.put(token.token_id, {});
    }

    /// A token is revoked if it (or any ancestor it was derived from) has
    /// been explicitly revoked. This gives revocation "cascade" semantics
    /// without needing to enumerate and mutate every descendant eagerly.
    pub fn isRevoked(self: *CapabilityManager, token: CapabilityToken) bool {
        if (token.revoked) return true;

        var current_id: ?u64 = token.token_id;
        while (current_id) |id| {
            if (self.revoked_tokens.contains(id)) return true;
            const record = self.issued.get(id) orelse return false;
            current_id = record.parent_token_id;
        }
        return false;
    }
};

pub fn issue(subject_id: u64, permissions: PermissionSet) CapabilityToken {
    return .{
        .token_id = 0,
        .subject_id = subject_id,
        .permissions = permissions,
        .revoked = false,
    };
}

pub fn authorize(token: CapabilityToken, permission: Permission) bool {
    if (token.revoked) return false;
    return token.permissions.contains(permission);
}

pub fn authorizeResource(token: CapabilityToken, handle: ResourceHandle) bool {
    if (!authorize(token, handle.required_permission)) return false;
    return token.subject_id == handle.owner_subject_id;
}
