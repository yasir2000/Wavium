//! Per-node service instance ownership: instead of one global
//! instance of a service, `InstanceTable` tracks one independent
//! instance per node (CPU or NUMA node - the prompt allows either
//! granularity, so this is generic over "node id" and the caller
//! decides what a node means). Activating a node's instance is a
//! one-time, local operation; there is no shared "the" instance any
//! two nodes contend over.

const service_kind = @import("service_kind.zig");

pub const NodeId = u16;
pub const max_nodes = 64;

pub const InstanceTable = struct {
    kind: service_kind.ServiceKind,
    active: [max_nodes]bool = undefined,
    node_count: usize,

    const Self = @This();

    /// Activates one instance of `kind` per node, for every node in
    /// `0..node_count` - "one instance per CPU or NUMA node".
    pub fn init(kind: service_kind.ServiceKind, node_count: usize) Self {
        var self: Self = .{ .kind = kind, .active = undefined, .node_count = node_count };
        for (&self.active) |*a| a.* = false;
        var i: usize = 0;
        while (i < node_count) : (i += 1) self.active[i] = true;
        return self;
    }

    pub fn isActive(self: *const Self, node: NodeId) bool {
        if (node >= self.node_count) return false;
        return self.active[node];
    }

    pub fn activeCount(self: *const Self) usize {
        var count: usize = 0;
        var i: usize = 0;
        while (i < self.node_count) : (i += 1) {
            if (self.active[i]) count += 1;
        }
        return count;
    }

    /// Takes a node's instance offline (e.g. node failure/hotplug
    /// removal) without affecting any other node's instance.
    pub fn deactivate(self: *Self, node: NodeId) void {
        if (node >= self.node_count) return;
        self.active[node] = false;
    }
};

const testing = @import("std").testing;

test "InstanceTable activates exactly one instance per node" {
    const table = InstanceTable.init(.scheduler, 4);
    try testing.expectEqual(@as(usize, 4), table.activeCount());
    try testing.expect(table.isActive(0));
    try testing.expect(table.isActive(3));
    try testing.expect(!table.isActive(4));
}

test "InstanceTable deactivate only affects the targeted node" {
    var table = InstanceTable.init(.capability_manager, 3);
    table.deactivate(1);
    try testing.expect(table.isActive(0));
    try testing.expect(!table.isActive(1));
    try testing.expect(table.isActive(2));
    try testing.expectEqual(@as(usize, 2), table.activeCount());
}
