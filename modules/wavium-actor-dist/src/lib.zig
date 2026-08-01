const std = @import("std");

/// Distributed actor execution: each actor owns a mailbox, state, and a
/// capability set, and the scheduler distributes actors across cores.
/// This module ties together ownership tracking (ownership.zig), message
/// routing between local execution and remote delivery
/// (mailbox_router.zig), placement/load-balancing decisions
/// (distribution.zig), and pin-aware migration (migration.zig). It builds
/// on top of wavium-smp (core identity/topology) and wavium-coresched
/// (per-core scheduling/queues) via the same function-pointer decoupling
/// pattern used throughout this codebase, rather than importing them
/// directly.
pub fn moduleName() []const u8 {
    return "wavium-actor-dist";
}

pub const ownership = @import("ownership.zig");
pub const mailbox_router = @import("mailbox_router.zig");
pub const distribution = @import("distribution.zig");
pub const migration = @import("migration.zig");

test "moduleName" {
    try std.testing.expectEqualStrings("wavium-actor-dist", moduleName());
}

var delivered_local: usize = 0;
var delivered_remote: usize = 0;

fn recordLocal(_: ownership.ActorId, _: u64) bool {
    delivered_local += 1;
    return true;
}
fn recordRemote(_: ownership.ActorId, _: u64) bool {
    delivered_remote += 1;
    return true;
}

test "end-to-end: place, route, and migrate an actor across cores" {
    delivered_local = 0;
    delivered_remote = 0;

    var table = ownership.OwnershipTable.init();

    const descriptor = distribution.ActorDescriptor{
        .id = 1,
        .capabilities = (1 << 0),
        .pinned_core = null,
    };
    const loads = [_]distribution.CoreLoad{
        .{ .core_id = 0, .actor_count = 3 },
        .{ .core_id = 1, .actor_count = 1 },
    };

    // Load balancing picks the least-loaded core for initial placement.
    const home_core = try distribution.chooseCore(descriptor, loads[0..]);
    try std.testing.expectEqual(@as(ownership.CoreId, 1), home_core);
    try table.register(descriptor.id, home_core);

    // Local delivery: router runs from the owning core.
    const local_router = mailbox_router.MailboxRouter{
        .ownership_table = &table,
        .local_core = home_core,
        .deliver_local = recordLocal,
        .deliver_remote = recordRemote,
    };
    try std.testing.expectEqual(mailbox_router.Destination.local, try local_router.route(descriptor.id, 7));
    try std.testing.expectEqual(@as(usize, 1), delivered_local);

    // Remote delivery: router runs from a different core.
    const remote_router = mailbox_router.MailboxRouter{
        .ownership_table = &table,
        .local_core = 0,
        .deliver_local = recordLocal,
        .deliver_remote = recordRemote,
    };
    try std.testing.expectEqual(mailbox_router.Destination.remote, try remote_router.route(descriptor.id, 8));
    try std.testing.expectEqual(@as(usize, 1), delivered_remote);

    // Migrate ownership to core 0 and confirm routing now favors it locally.
    try migration.migrateActor(&table, descriptor, 0);
    try std.testing.expectEqual(mailbox_router.Destination.local, try remote_router.route(descriptor.id, 9));
    try std.testing.expectEqual(@as(usize, 2), delivered_local);
}
