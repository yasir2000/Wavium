const std = @import("std");

pub const CoreId = u16;
pub const ActorId = u32;
pub const max_actors = 256;

pub const OwnershipError = error{
    ActorNotFound,
    RegistryFull,
    DuplicateActor,
};

pub const OwnershipEntry = struct {
    actor_id: ActorId,
    owner_core: CoreId,
    in_use: bool,
};

/// Tracks which core currently owns each actor's mailbox. "Ownership"
/// means the owning core is where the actor's mailbox lives and where its
/// messages are executed locally; every other core must route messages to
/// it remotely (see mailbox_router.zig).
pub const OwnershipTable = struct {
    entries: [max_actors]OwnershipEntry,
    count: usize,

    pub fn init() OwnershipTable {
        return .{ .entries = undefined, .count = 0 };
    }

    fn findIndex(self: *const OwnershipTable, actor_id: ActorId) ?usize {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.entries[i].in_use and self.entries[i].actor_id == actor_id) return i;
        }
        return null;
    }

    pub fn register(self: *OwnershipTable, actor_id: ActorId, owner_core: CoreId) OwnershipError!void {
        if (self.findIndex(actor_id) != null) return error.DuplicateActor;
        if (self.count >= max_actors) return error.RegistryFull;
        self.entries[self.count] = .{ .actor_id = actor_id, .owner_core = owner_core, .in_use = true };
        self.count += 1;
    }

    pub fn ownerOf(self: *const OwnershipTable, actor_id: ActorId) ?CoreId {
        const idx = self.findIndex(actor_id) orelse return null;
        return self.entries[idx].owner_core;
    }

    /// Reassigns `actor_id`'s owning core, e.g. after a migration decision.
    pub fn transfer(self: *OwnershipTable, actor_id: ActorId, new_owner: CoreId) OwnershipError!void {
        const idx = self.findIndex(actor_id) orelse return error.ActorNotFound;
        self.entries[idx].owner_core = new_owner;
    }

    pub fn unregister(self: *OwnershipTable, actor_id: ActorId) OwnershipError!void {
        const idx = self.findIndex(actor_id) orelse return error.ActorNotFound;
        self.entries[idx].in_use = false;
    }
};

test "register/ownerOf/transfer/unregister lifecycle" {
    var table = OwnershipTable.init();
    try table.register(1, 0);
    try std.testing.expectEqual(@as(?CoreId, 0), table.ownerOf(1));

    try table.transfer(1, 3);
    try std.testing.expectEqual(@as(?CoreId, 3), table.ownerOf(1));

    try table.unregister(1);
    try std.testing.expectEqual(@as(?CoreId, null), table.ownerOf(1));
}

test "register rejects duplicate actor ids" {
    var table = OwnershipTable.init();
    try table.register(5, 0);
    try std.testing.expectError(error.DuplicateActor, table.register(5, 1));
}

test "transfer and unregister report ActorNotFound for unknown actors" {
    var table = OwnershipTable.init();
    try std.testing.expectError(error.ActorNotFound, table.transfer(99, 1));
    try std.testing.expectError(error.ActorNotFound, table.unregister(99));
}
