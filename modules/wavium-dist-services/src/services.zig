//! Ties the 5 required distributed services together: each gets its
//! own `InstanceTable` (one instance per node), and access to any of
//! them is routed through the shared `SyncPolicy` so cross-node
//! access is the only path that ever pays a synchronization cost.

const service_kind = @import("service_kind.zig");
const instance_table = @import("instance_table.zig");
const router = @import("router.zig");
const sync = @import("sync.zig");

pub const ServiceKind = service_kind.ServiceKind;
pub const NodeId = instance_table.NodeId;

pub const DistributedServices = struct {
    node_count: usize,
    memory_manager: instance_table.InstanceTable,
    scheduler: instance_table.InstanceTable,
    capability_manager: instance_table.InstanceTable,
    registry: instance_table.InstanceTable,
    timers: instance_table.InstanceTable,
    sync_policy: sync.SyncPolicy,

    const Self = @This();

    pub fn init(node_count: usize, sync_fn: sync.SyncFn) Self {
        return .{
            .node_count = node_count,
            .memory_manager = instance_table.InstanceTable.init(.memory_manager, node_count),
            .scheduler = instance_table.InstanceTable.init(.scheduler, node_count),
            .capability_manager = instance_table.InstanceTable.init(.capability_manager, node_count),
            .registry = instance_table.InstanceTable.init(.registry, node_count),
            .timers = instance_table.InstanceTable.init(.timers, node_count),
            .sync_policy = sync.SyncPolicy.init(sync_fn),
        };
    }

    fn tableFor(self: *Self, kind: ServiceKind) *instance_table.InstanceTable {
        return switch (kind) {
            .memory_manager => &self.memory_manager,
            .scheduler => &self.scheduler,
            .capability_manager => &self.capability_manager,
            .registry => &self.registry,
            .timers => &self.timers,
        };
    }

    /// Every service has an active instance on every node - true
    /// distributed placement, not a single shared owner.
    pub fn isActiveEverywhere(self: *Self, kind: ServiceKind) bool {
        return self.tableFor(kind).activeCount() == self.node_count;
    }

    /// Access a key-addressed service instance from `local_node`.
    /// Routes the key to its home node, then only synchronizes if
    /// that home node differs from `local_node`.
    pub fn access(self: *Self, kind: ServiceKind, local_node: NodeId, key: u64, reason: sync.SyncReason) bool {
        const home = router.homeNodeFor(key, self.node_count);
        if (!self.tableFor(kind).isActive(home)) return false;
        return self.sync_policy.maybeSync(local_node, home, reason);
    }
};

const testing = @import("std").testing;

fn testSyncFn(from: NodeId, to: NodeId, reason: sync.SyncReason) bool {
    _ = from;
    _ = to;
    _ = reason;
    return true;
}

test "DistributedServices places one instance of every service per node" {
    var services = DistributedServices.init(4, testSyncFn);
    inline for (.{ ServiceKind.memory_manager, ServiceKind.scheduler, ServiceKind.capability_manager, ServiceKind.registry, ServiceKind.timers }) |kind| {
        try testing.expect(services.isActiveEverywhere(kind));
    }
}

test "access takes the local fast path when the key's home node is local" {
    var services = DistributedServices.init(2, testSyncFn);
    // Find a key whose home node is 0.
    var key: u64 = 0;
    while (router.homeNodeFor(key, 2) != 0) : (key += 1) {}
    const ok = services.access(.registry, 0, key, .cross_node_read);
    try testing.expect(ok);
    try testing.expectEqual(@as(usize, 1), services.sync_policy.stats.local_fast_path);
}

test "access triggers cross-node sync when the key's home node differs" {
    var services = DistributedServices.init(2, testSyncFn);
    var key: u64 = 0;
    while (router.homeNodeFor(key, 2) != 1) : (key += 1) {}
    const ok = services.access(.timers, 0, key, .migration);
    try testing.expect(ok);
    try testing.expectEqual(@as(usize, 1), services.sync_policy.stats.cross_node_syncs);
}
