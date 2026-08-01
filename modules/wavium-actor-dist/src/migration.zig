const std = @import("std");
const ownership = @import("ownership.zig");
const distribution = @import("distribution.zig");

pub const MigrationError = error{
    ActorNotFound,
    PinnedElsewhere,
};

/// Migrates `descriptor`'s ownership to `target_core`. Pinned actors can
/// only ever "migrate" to their own pinned core (i.e. migration to any
/// other core is rejected), which is what makes pinning meaningful for the
/// load balancer in distribution.zig.
pub fn migrateActor(
    table: *ownership.OwnershipTable,
    descriptor: distribution.ActorDescriptor,
    target_core: ownership.CoreId,
) MigrationError!void {
    if (descriptor.pinned_core) |pinned| {
        if (pinned != target_core) return error.PinnedElsewhere;
    }
    table.transfer(descriptor.id, target_core) catch return error.ActorNotFound;
}

test "migrateActor moves ownership for an unpinned actor" {
    var table = ownership.OwnershipTable.init();
    try table.register(1, 0);
    const descriptor = distribution.ActorDescriptor{ .id = 1, .capabilities = 0, .pinned_core = null };

    try migrateActor(&table, descriptor, 3);
    try std.testing.expectEqual(@as(?ownership.CoreId, 3), table.ownerOf(1));
}

test "migrateActor rejects moving a pinned actor to a different core" {
    var table = ownership.OwnershipTable.init();
    try table.register(1, 2);
    const descriptor = distribution.ActorDescriptor{ .id = 1, .capabilities = 0, .pinned_core = 2 };

    try std.testing.expectError(error.PinnedElsewhere, migrateActor(&table, descriptor, 5));
    try std.testing.expectEqual(@as(?ownership.CoreId, 2), table.ownerOf(1));
}

test "migrateActor allows a pinned actor to its own pinned core" {
    var table = ownership.OwnershipTable.init();
    try table.register(1, 2);
    const descriptor = distribution.ActorDescriptor{ .id = 1, .capabilities = 0, .pinned_core = 2 };

    try migrateActor(&table, descriptor, 2);
    try std.testing.expectEqual(@as(?ownership.CoreId, 2), table.ownerOf(1));
}

test "migrateActor surfaces ActorNotFound for an unregistered actor" {
    var table = ownership.OwnershipTable.init();
    const descriptor = distribution.ActorDescriptor{ .id = 42, .capabilities = 0, .pinned_core = null };
    try std.testing.expectError(error.ActorNotFound, migrateActor(&table, descriptor, 1));
}
