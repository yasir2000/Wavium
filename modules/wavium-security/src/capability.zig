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

pub const CapabilityManager = struct {
    allocator: std.mem.Allocator,
    next_token_id: u64,
    revoked_tokens: std.AutoHashMap(u64, void),

    pub fn init(allocator: std.mem.Allocator) CapabilityManager {
        return .{
            .allocator = allocator,
            .next_token_id = 1,
            .revoked_tokens = std.AutoHashMap(u64, void).init(allocator),
        };
    }

    pub fn deinit(self: *CapabilityManager) void {
        self.revoked_tokens.deinit();
    }

    pub fn issue(self: *CapabilityManager, subject_id: u64, permissions: PermissionSet) CapabilityToken {
        const token = CapabilityToken{
            .token_id = self.next_token_id,
            .subject_id = subject_id,
            .permissions = permissions,
            .revoked = false,
        };
        self.next_token_id += 1;
        return token;
    }

    pub fn revoke(self: *CapabilityManager, token: *CapabilityToken) !void {
        token.revoked = true;
        try self.revoked_tokens.put(token.token_id, {});
    }

    pub fn isRevoked(self: *CapabilityManager, token: CapabilityToken) bool {
        if (token.revoked) return true;
        return self.revoked_tokens.contains(token.token_id);
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
