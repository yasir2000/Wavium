const std = @import("std");
const node_mod = @import("node.zig");

pub const AllocError = error{
    AllocationFailed,
    NodeNotFound,
};

/// Decoupling seam for actually reserving memory on a given NUMA node,
/// returning an opaque handle/address, or null on local exhaustion. A
/// real implementation binds this to the underlying memory manager
/// (e.g. modules/wavium-memory) per node.
pub const AllocFn = *const fn (node_id: node_mod.NumaNodeId, size: usize) ?u64;

/// NUMA-aware allocation: always tries `preferred_node` first (local
/// memory preference); if that node is exhausted, falls back to the
/// nearest remaining node by topology distance.
pub const NodeAllocator = struct {
    topology: *const node_mod.NumaTopology,
    alloc_fn: AllocFn,

    pub fn allocateOn(self: NodeAllocator, preferred_node: node_mod.NumaNodeId, size: usize) AllocError!u64 {
        if (self.topology.get(preferred_node) == null) return error.NodeNotFound;
        if (self.alloc_fn(preferred_node, size)) |handle| return handle;

        var best_node: ?node_mod.NumaNodeId = null;
        var best_distance: u8 = std.math.maxInt(u8);
        var i: usize = 0;
        while (i < self.topology.count) : (i += 1) {
            const candidate = self.topology.nodes[i].id;
            if (candidate == preferred_node) continue;
            const dist = self.topology.distanceBetween(preferred_node, candidate) catch continue;
            if (dist < best_distance) {
                best_distance = dist;
                best_node = candidate;
            }
        }

        if (best_node) |node_id| {
            if (self.alloc_fn(node_id, size)) |handle| return handle;
        }
        return error.AllocationFailed;
    }
};

fn alwaysSucceeds(node_id: node_mod.NumaNodeId, _: usize) ?u64 {
    return @as(u64, node_id) + 1000;
}
fn onlyNodeOneSucceeds(node_id: node_mod.NumaNodeId, _: usize) ?u64 {
    if (node_id == 1) return 1234;
    return null;
}
fn alwaysFails(_: node_mod.NumaNodeId, _: usize) ?u64 {
    return null;
}

test "allocateOn prefers the requested node when it can satisfy the request" {
    const topo = try node_mod.detect(2, 1, 1 << 20);
    const allocator = NodeAllocator{ .topology = &topo, .alloc_fn = alwaysSucceeds };
    try std.testing.expectEqual(@as(u64, 1000), try allocator.allocateOn(0, 64));
}

test "allocateOn falls back to another node when the preferred node is exhausted" {
    const topo = try node_mod.detect(2, 1, 1 << 20);
    const allocator = NodeAllocator{ .topology = &topo, .alloc_fn = onlyNodeOneSucceeds };
    try std.testing.expectEqual(@as(u64, 1234), try allocator.allocateOn(0, 64));
}

test "allocateOn reports AllocationFailed when every node is exhausted" {
    const topo = try node_mod.detect(2, 1, 1 << 20);
    const allocator = NodeAllocator{ .topology = &topo, .alloc_fn = alwaysFails };
    try std.testing.expectError(error.AllocationFailed, allocator.allocateOn(0, 64));
}

test "allocateOn reports NodeNotFound for a node outside the topology" {
    const topo = try node_mod.detect(1, 1, 1 << 20);
    const allocator = NodeAllocator{ .topology = &topo, .alloc_fn = alwaysSucceeds };
    try std.testing.expectError(error.NodeNotFound, allocator.allocateOn(5, 64));
}
