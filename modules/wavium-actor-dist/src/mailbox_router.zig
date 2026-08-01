const std = @import("std");
const ownership = @import("ownership.zig");

/// Decoupling seam for actually handing a message to an actor's mailbox.
/// Returns true on successful delivery. A real implementation binds
/// `deliver_local` to the local per-core mailbox storage and
/// `deliver_remote` to the cross-core IPC/IPI transport (Prompt 20).
pub const DeliverFn = *const fn (actor_id: ownership.ActorId, message: u64) bool;

pub const RouteError = error{
    ActorNotFound,
    DeliveryFailed,
};

pub const Destination = enum { local, remote };

/// Decides whether a message for `actor_id` should be executed locally or
/// forwarded remotely, based on the current ownership table, then invokes
/// the matching delivery seam.
pub const MailboxRouter = struct {
    ownership_table: *ownership.OwnershipTable,
    local_core: ownership.CoreId,
    deliver_local: DeliverFn,
    deliver_remote: DeliverFn,

    pub fn route(self: *const MailboxRouter, actor_id: ownership.ActorId, message: u64) RouteError!Destination {
        const owner = self.ownership_table.ownerOf(actor_id) orelse return error.ActorNotFound;
        if (owner == self.local_core) {
            if (!self.deliver_local(actor_id, message)) return error.DeliveryFailed;
            return .local;
        }
        if (!self.deliver_remote(actor_id, message)) return error.DeliveryFailed;
        return .remote;
    }
};

fn alwaysDeliver(_: ownership.ActorId, _: u64) bool {
    return true;
}
fn alwaysFail(_: ownership.ActorId, _: u64) bool {
    return false;
}

test "route delivers locally when the actor is owned by the local core" {
    var table = ownership.OwnershipTable.init();
    try table.register(1, 0);

    const router = MailboxRouter{
        .ownership_table = &table,
        .local_core = 0,
        .deliver_local = alwaysDeliver,
        .deliver_remote = alwaysDeliver,
    };

    try std.testing.expectEqual(Destination.local, try router.route(1, 42));
}

test "route delivers remotely when the actor is owned by a different core" {
    var table = ownership.OwnershipTable.init();
    try table.register(1, 7);

    const router = MailboxRouter{
        .ownership_table = &table,
        .local_core = 0,
        .deliver_local = alwaysDeliver,
        .deliver_remote = alwaysDeliver,
    };

    try std.testing.expectEqual(Destination.remote, try router.route(1, 42));
}

test "route surfaces ActorNotFound and DeliveryFailed" {
    var table = ownership.OwnershipTable.init();
    try table.register(1, 0);

    const failing_router = MailboxRouter{
        .ownership_table = &table,
        .local_core = 0,
        .deliver_local = alwaysFail,
        .deliver_remote = alwaysDeliver,
    };
    try std.testing.expectError(error.DeliveryFailed, failing_router.route(1, 1));

    const ok_router = MailboxRouter{
        .ownership_table = &table,
        .local_core = 0,
        .deliver_local = alwaysDeliver,
        .deliver_remote = alwaysDeliver,
    };
    try std.testing.expectError(error.ActorNotFound, ok_router.route(999, 1));
}
