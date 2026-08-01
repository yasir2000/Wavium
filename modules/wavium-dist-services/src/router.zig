//! Routes a key (actor id, capability token id, timer id, memory
//! region id, ...) to its home node. Deliberately a fresh, simple
//! local hash - NOT a reuse of `wavium-massive-parallel`'s
//! `sharding.computeShard` (Prompt 27) - kept decoupled per this
//! repo's one-new-module-per-prompt convention, and this module
//! operates at a coarser CPU/NUMA-node granularity rather than
//! `wavium-massive-parallel`'s many-shard granularity.

const instance_table = @import("instance_table.zig");

/// A cheap multiplicative hash so any node can independently compute
/// which node owns a given key - no lookup table, no coordination.
pub fn homeNodeFor(key: u64, node_count: usize) instance_table.NodeId {
    if (node_count == 0) return 0;
    const mixed = key *% 0x9E3779B97F4A7C15;
    return @intCast((mixed >> 32) % node_count);
}

const testing = @import("std").testing;

test "homeNodeFor is deterministic for the same key and node_count" {
    const a = homeNodeFor(1234, 8);
    const b = homeNodeFor(1234, 8);
    try testing.expectEqual(a, b);
    try testing.expect(a < 8);
}

test "homeNodeFor spreads keys across all nodes" {
    var seen: [4]bool = undefined;
    for (&seen) |*s| s.* = false;
    var key: u64 = 0;
    while (key < 2048) : (key += 1) {
        seen[homeNodeFor(key, 4)] = true;
    }
    for (seen) |s| try testing.expect(s);
}
