//! Distributed metadata store: cluster-wide configuration/metadata
//! (e.g. per-node descriptors, feature flags, topology summaries) is
//! sharded the same way as the actor registry, so no single "metadata
//! service" instance becomes a bottleneck or synchronization point as
//! the system scales toward 1024 logical CPUs.

const sharding = @import("sharding.zig");

pub const MetadataKey = u64;

pub const MetadataError = error{
    KeyNotFound,
    ShardFull,
};

fn Shard(comptime V: type, comptime capacity: usize) type {
    return struct {
        keys: [capacity]MetadataKey = undefined,
        values: [capacity]V = undefined,
        occupied: [capacity]bool = undefined,
        count: usize = 0,

        const Self = @This();

        fn init() Self {
            var self: Self = .{ .keys = undefined, .values = undefined, .occupied = undefined, .count = 0 };
            for (&self.occupied) |*o| o.* = false;
            return self;
        }

        fn find(self: *const Self, key: MetadataKey) ?usize {
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                if (self.occupied[i] and self.keys[i] == key) return i;
            }
            return null;
        }

        fn put(self: *Self, key: MetadataKey, value: V) MetadataError!void {
            if (self.find(key)) |idx| {
                self.values[idx] = value;
                return;
            }
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                if (!self.occupied[i]) {
                    self.keys[i] = key;
                    self.values[i] = value;
                    self.occupied[i] = true;
                    self.count += 1;
                    return;
                }
            }
            return MetadataError.ShardFull;
        }

        fn get(self: *const Self, key: MetadataKey) MetadataError!V {
            const idx = self.find(key) orelse return MetadataError.KeyNotFound;
            return self.values[idx];
        }

        fn remove(self: *Self, key: MetadataKey) MetadataError!void {
            const idx = self.find(key) orelse return MetadataError.KeyNotFound;
            self.occupied[idx] = false;
            self.count -= 1;
        }
    };
}

/// A sharded metadata key-value store, generic over the value type
/// `V` and the per-shard capacity (`entries_per_shard`).
pub fn DistributedMetadataStore(comptime V: type, comptime max_shards: usize, comptime entries_per_shard: usize) type {
    const ShardT = Shard(V, entries_per_shard);
    return struct {
        shards: [max_shards]ShardT = undefined,
        shard_count: usize,

        const Self = @This();

        pub fn init(shard_count: usize) Self {
            var self: Self = .{ .shards = undefined, .shard_count = shard_count };
            for (&self.shards) |*s| s.* = ShardT.init();
            return self;
        }

        fn shardFor(self: *const Self, key: MetadataKey) *ShardT {
            const idx = sharding.computeShard(key, self.shard_count);
            return @constCast(&self.shards[idx]);
        }

        pub fn put(self: *Self, key: MetadataKey, value: V) MetadataError!void {
            return self.shardFor(key).put(key, value);
        }

        pub fn get(self: *const Self, key: MetadataKey) MetadataError!V {
            return self.shardFor(key).get(key);
        }

        pub fn remove(self: *Self, key: MetadataKey) MetadataError!void {
            return self.shardFor(key).remove(key);
        }
    };
}

const testing = @import("std").testing;

test "DistributedMetadataStore put/get roundtrips across shards" {
    var store = DistributedMetadataStore(u32, 8, 16).init(8);
    try store.put(1, 100);
    try store.put(2, 200);
    try testing.expectEqual(@as(u32, 100), try store.get(1));
    try testing.expectEqual(@as(u32, 200), try store.get(2));
}

test "DistributedMetadataStore put overwrites existing key" {
    var store = DistributedMetadataStore(u32, 4, 8).init(4);
    try store.put(9, 1);
    try store.put(9, 2);
    try testing.expectEqual(@as(u32, 2), try store.get(9));
}

test "DistributedMetadataStore remove and not-found errors" {
    var store = DistributedMetadataStore(bool, 4, 8).init(4);
    try store.put(3, true);
    try store.remove(3);
    try testing.expectError(MetadataError.KeyNotFound, store.get(3));
    try testing.expectError(MetadataError.KeyNotFound, store.remove(3));
}
