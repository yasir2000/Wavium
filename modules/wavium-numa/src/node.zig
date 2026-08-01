const std = @import("std");

pub const NumaNodeId = u8;
pub const CoreId = u16;
pub const max_nodes = 16;

pub const NumaError = error{
    TooManyNodes,
    NodeNotFound,
};

pub const NumaNode = struct {
    id: NumaNodeId,
    core_mask: u64,
    memory_bytes: u64,
};

/// NUMA topology: the set of detected nodes plus a symmetric node-to-node
/// distance matrix (relative memory access cost, ACPI-SLIT-style: 10 is
/// "local", larger numbers are progressively more remote).
pub const NumaTopology = struct {
    nodes: [max_nodes]NumaNode,
    distance: [max_nodes][max_nodes]u8,
    count: usize,

    pub fn init() NumaTopology {
        return .{ .nodes = undefined, .distance = undefined, .count = 0 };
    }

    pub fn get(self: *const NumaTopology, node_id: NumaNodeId) ?NumaNode {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.nodes[i].id == node_id) return self.nodes[i];
        }
        return null;
    }

    pub fn distanceBetween(self: *const NumaTopology, a: NumaNodeId, b: NumaNodeId) NumaError!u8 {
        if (a >= self.count or b >= self.count) return error.NodeNotFound;
        return self.distance[a][b];
    }
};

/// Deterministically detects `node_count` NUMA nodes, each owning
/// `cores_per_node` contiguous cores. Distance is `10` to oneself, `20` to
/// any other node - a simple flat model standing in for what ACPI SLIT /
/// device-tree `numa-node-id` would report on real hardware.
pub fn detect(node_count: usize, cores_per_node: usize, memory_bytes_per_node: u64) NumaError!NumaTopology {
    if (node_count > max_nodes) return error.TooManyNodes;

    var topo = NumaTopology.init();
    var node: usize = 0;
    while (node < node_count) : (node += 1) {
        var mask: u64 = 0;
        var c: usize = 0;
        while (c < cores_per_node) : (c += 1) {
            const core_id = node * cores_per_node + c;
            if (core_id < 64) mask |= (@as(u64, 1) << @intCast(core_id));
        }
        topo.nodes[node] = .{ .id = @intCast(node), .core_mask = mask, .memory_bytes = memory_bytes_per_node };
    }
    topo.count = node_count;

    var i: usize = 0;
    while (i < node_count) : (i += 1) {
        var j: usize = 0;
        while (j < node_count) : (j += 1) {
            topo.distance[i][j] = if (i == j) 10 else 20;
        }
    }
    return topo;
}

test "detect assigns contiguous core masks and a flat local/remote distance matrix" {
    const topo = try detect(2, 4, 1 << 30);
    try std.testing.expectEqual(@as(usize, 2), topo.count);
    try std.testing.expectEqual(@as(u64, 0b1111), topo.get(0).?.core_mask);
    try std.testing.expectEqual(@as(u64, 0b11110000), topo.get(1).?.core_mask);

    try std.testing.expectEqual(@as(u8, 10), try topo.distanceBetween(0, 0));
    try std.testing.expectEqual(@as(u8, 20), try topo.distanceBetween(0, 1));
}

test "detect rejects requests for more nodes than max_nodes" {
    try std.testing.expectError(error.TooManyNodes, detect(max_nodes + 1, 1, 0));
}

test "distanceBetween reports NodeNotFound for an out-of-range node" {
    const topo = try detect(1, 1, 0);
    try std.testing.expectError(error.NodeNotFound, topo.distanceBetween(0, 5));
}
