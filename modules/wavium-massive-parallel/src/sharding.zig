//! Sharding utilities: routes a key (actor id, metadata key, etc.) to
//! one of a fixed number of shards using a cheap, deterministic hash,
//! so ownership of any given key is decided independently by every
//! participant without consulting a central authority (a prerequisite
//! for "no centralized scheduler" / "minimal synchronization").

const std = @import("std");

pub const ShardId = usize;

/// Deterministically maps `key` to a shard in `[0, shard_count)`.
/// Any core can compute this locally and always gets the same answer
/// for the same key - no lookup table or coordination required.
pub fn computeShard(key: u64, shard_count: usize) ShardId {
    if (shard_count == 0) return 0;
    const hashed = std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
    return @intCast(hashed % shard_count);
}

const testing = std.testing;

test "computeShard is deterministic for the same key and shard_count" {
    const a = computeShard(42, 16);
    const b = computeShard(42, 16);
    try testing.expectEqual(a, b);
    try testing.expect(a < 16);
}

test "computeShard spreads keys across all shards" {
    var seen: [8]bool = undefined;
    for (&seen) |*s| s.* = false;
    var key: u64 = 0;
    while (key < 4096) : (key += 1) {
        seen[computeShard(key, 8)] = true;
    }
    for (seen) |s| try testing.expect(s);
}
