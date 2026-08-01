//! Distributed actor registry: actor ownership is split across a
//! fixed number of shards (via `sharding.computeShard`), each shard a
//! small independent table. Looking up or registering an actor only
//! ever touches the ONE shard that owns it - no global lock, no
//! single registry structure any core must serialize through. This
//! is deliberately a fresh, decoupled type (not a reuse of
//! `wavium-actor-dist`'s `OwnershipTable` from Prompt 19): that
//! module models single-core-granularity ownership for a modest
//! actor count, whereas this one models registry SHARDING itself so
//! it scales to the 1024-logical-CPU tier this prompt targets.

const sharding = @import("sharding.zig");

pub const ActorId = u64;
pub const CoreId = u16;

pub const RegistryError = error{
    ActorNotFound,
    DuplicateActor,
    ShardFull,
};

const max_entries_per_shard = 64;

const ShardEntry = struct {
    actor_id: ActorId,
    owner: CoreId,
    occupied: bool = false,
};

const RegistryShard = struct {
    entries: [max_entries_per_shard]ShardEntry = undefined,
    count: usize = 0,

    fn init() RegistryShard {
        var self: RegistryShard = .{ .entries = undefined, .count = 0 };
        for (&self.entries) |*e| e.* = .{ .actor_id = 0, .owner = 0, .occupied = false };
        return self;
    }

    fn find(self: *const RegistryShard, actor_id: ActorId) ?usize {
        var i: usize = 0;
        while (i < self.entries.len) : (i += 1) {
            if (self.entries[i].occupied and self.entries[i].actor_id == actor_id) return i;
        }
        return null;
    }

    fn register(self: *RegistryShard, actor_id: ActorId, owner: CoreId) RegistryError!void {
        if (self.find(actor_id) != null) return RegistryError.DuplicateActor;
        var i: usize = 0;
        while (i < self.entries.len) : (i += 1) {
            if (!self.entries[i].occupied) {
                self.entries[i] = .{ .actor_id = actor_id, .owner = owner, .occupied = true };
                self.count += 1;
                return;
            }
        }
        return RegistryError.ShardFull;
    }

    fn lookup(self: *const RegistryShard, actor_id: ActorId) RegistryError!CoreId {
        const idx = self.find(actor_id) orelse return RegistryError.ActorNotFound;
        return self.entries[idx].owner;
    }

    fn unregister(self: *RegistryShard, actor_id: ActorId) RegistryError!void {
        const idx = self.find(actor_id) orelse return RegistryError.ActorNotFound;
        self.entries[idx].occupied = false;
        self.count -= 1;
    }
};

/// A sharded actor registry supporting up to `max_shards` shards
/// (chosen at construction time to match a deployment's core/group
/// count, e.g. via `scaling.groupCountFor`).
pub fn DistributedActorRegistry(comptime max_shards: usize) type {
    return struct {
        shards: [max_shards]RegistryShard = undefined,
        shard_count: usize,

        const Self = @This();

        pub fn init(shard_count: usize) Self {
            var self: Self = .{ .shards = undefined, .shard_count = shard_count };
            for (&self.shards) |*s| s.* = RegistryShard.init();
            return self;
        }

        fn shardFor(self: *const Self, actor_id: ActorId) *RegistryShard {
            const idx = sharding.computeShard(actor_id, self.shard_count);
            return @constCast(&self.shards[idx]);
        }

        pub fn register(self: *Self, actor_id: ActorId, owner: CoreId) RegistryError!void {
            return self.shardFor(actor_id).register(actor_id, owner);
        }

        pub fn lookup(self: *const Self, actor_id: ActorId) RegistryError!CoreId {
            return self.shardFor(actor_id).lookup(actor_id);
        }

        pub fn unregister(self: *Self, actor_id: ActorId) RegistryError!void {
            return self.shardFor(actor_id).unregister(actor_id);
        }

        pub fn totalCount(self: *const Self) usize {
            var total: usize = 0;
            var i: usize = 0;
            while (i < self.shard_count) : (i += 1) total += self.shards[i].count;
            return total;
        }
    };
}

const testing = @import("std").testing;

test "DistributedActorRegistry registers and looks up across shards" {
    var registry = DistributedActorRegistry(16).init(16);
    try registry.register(1, 3);
    try registry.register(2, 7);
    try testing.expectEqual(@as(CoreId, 3), try registry.lookup(1));
    try testing.expectEqual(@as(CoreId, 7), try registry.lookup(2));
    try testing.expectEqual(@as(usize, 2), registry.totalCount());
}

test "DistributedActorRegistry rejects duplicate registration and unknown lookups" {
    var registry = DistributedActorRegistry(8).init(8);
    try registry.register(10, 1);
    try testing.expectError(RegistryError.DuplicateActor, registry.register(10, 2));
    try testing.expectError(RegistryError.ActorNotFound, registry.lookup(999));
}

test "DistributedActorRegistry unregister frees the slot for reuse" {
    var registry = DistributedActorRegistry(4).init(4);
    try registry.register(5, 0);
    try registry.unregister(5);
    try testing.expectError(RegistryError.ActorNotFound, registry.lookup(5));
    try registry.register(5, 1);
    try testing.expectEqual(@as(CoreId, 1), try registry.lookup(5));
}
