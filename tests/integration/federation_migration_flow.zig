const std = @import("std");
const actor = @import("wavium-actor");
const state = @import("wavium-state");
const federation = @import("wavium-federation");
const security = @import("wavium-security");

fn authorizeMigration(ctx: *const anyopaque, permission: federation.MigrationPermission) bool {
    const token: *const security.CapabilityToken = @ptrCast(@alignCast(ctx));
    return switch (permission) {
        .component_migrate => security.authorize(token.*, .component_migrate),
    };
}

test "federation migration ticket with actor and state" {
    const a = actor.ActorRef{ .id = 77, .status = .active };
    const s = state.ActorStateRecord{ .actor_id = a.id, .version = 3, .bytes = "snapshot-v3" };

    var perms = security.PermissionSet.empty;
    perms.insert(.component_migrate);
    const token = security.issue(500, perms);
    const token_ctx: *const anyopaque = @ptrCast(&token);

    const ticket = try federation.planMigrationAuthorized(a.id, 10, 20, s.version, token_ctx, authorizeMigration);
    try federation.validateMigration(ticket);

    try std.testing.expectEqual(@as(u64, 77), ticket.actor_id);
    try std.testing.expectEqual(@as(u64, 3), ticket.state_version);
    try std.testing.expectError(error.InvalidMigrationRoute, federation.planMigration(a.id, 10, 10, s.version));

    const denied_token = security.issue(501, security.PermissionSet.empty);
    const denied_ctx: *const anyopaque = @ptrCast(&denied_token);
    try std.testing.expectError(
        error.PermissionDenied,
        federation.planMigrationAuthorized(a.id, 10, 20, s.version, denied_ctx, authorizeMigration),
    );
}
