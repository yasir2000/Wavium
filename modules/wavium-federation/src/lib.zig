const std = @import("std");

pub const NodeId = u64;

pub const DiscoveryRecord = struct {
    node_id: NodeId,
    address: []const u8,
};

pub const MigrationTicket = struct {
    actor_id: u64,
    from_node: NodeId,
    to_node: NodeId,
    state_version: u64,
};

pub const MigrationPermission = enum {
    component_migrate,
};

pub const AuthorizationFn = *const fn (ctx: *const anyopaque, permission: MigrationPermission) bool;

pub fn planMigration(actor_id: u64, from_node: NodeId, to_node: NodeId, state_version: u64) !MigrationTicket {
    if (from_node == to_node) return error.InvalidMigrationRoute;
    return .{
        .actor_id = actor_id,
        .from_node = from_node,
        .to_node = to_node,
        .state_version = state_version,
    };
}

pub fn validateMigration(ticket: MigrationTicket) !void {
    if (ticket.actor_id == 0) return error.InvalidActorId;
    if (ticket.from_node == ticket.to_node) return error.InvalidMigrationRoute;
}

pub fn planMigrationAuthorized(
    actor_id: u64,
    from_node: NodeId,
    to_node: NodeId,
    state_version: u64,
    auth_ctx: *const anyopaque,
    authorize: AuthorizationFn,
) !MigrationTicket {
    if (!authorize(auth_ctx, .component_migrate)) return error.PermissionDenied;
    return planMigration(actor_id, from_node, to_node, state_version);
}

test "discovery record fields" {
    const d = DiscoveryRecord{ .node_id = 1, .address = "local" };
    try std.testing.expectEqual(@as(NodeId, 1), d.node_id);
}

test "migration planning and validation" {
    const ticket = try planMigration(9, 1, 2, 7);
    try validateMigration(ticket);

    try std.testing.expectError(error.InvalidMigrationRoute, planMigration(9, 1, 1, 7));
}

fn allowMigration(_: *const anyopaque, permission: MigrationPermission) bool {
    return permission == .component_migrate;
}

fn denyMigration(_: *const anyopaque, _: MigrationPermission) bool {
    return false;
}

test "authorized migration policy" {
    const auth_ctx: *const anyopaque = @ptrFromInt(1);
    _ = try planMigrationAuthorized(99, 1, 2, 3, auth_ctx, allowMigration);
    try std.testing.expectError(error.PermissionDenied, planMigrationAuthorized(99, 1, 2, 3, auth_ctx, denyMigration));
}
