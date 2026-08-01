//! wavium-dist-services: converts the runtime's global services
//! (Memory Manager, Scheduler, Capability Manager, Registry, Timers)
//! into per-CPU/per-NUMA-node distributed instances that only
//! synchronize across nodes when strictly necessary.
//!
//! Repository: runtime/services/ (this module).

pub const service_kind = @import("service_kind.zig");
pub const instance_table = @import("instance_table.zig");
pub const router = @import("router.zig");
pub const sync = @import("sync.zig");
pub const services = @import("services.zig");

pub const ServiceKind = service_kind.ServiceKind;
pub const NodeId = instance_table.NodeId;
pub const InstanceTable = instance_table.InstanceTable;
pub const SyncReason = sync.SyncReason;
pub const SyncPolicy = sync.SyncPolicy;
pub const DistributedServices = services.DistributedServices;

pub fn moduleName() []const u8 {
    return "wavium-dist-services";
}

const testing = @import("std").testing;

fn integrationSyncFn(from: NodeId, to: NodeId, reason: SyncReason) bool {
    _ = from;
    _ = to;
    _ = reason;
    return true;
}

test "moduleName" {
    try testing.expectEqualStrings("wavium-dist-services", moduleName());
}

test "end-to-end: 8-node deployment of all 5 distributed services" {
    var dist = DistributedServices.init(8, integrationSyncFn);

    inline for (service_kind.service_kinds) |kind| {
        try testing.expect(dist.isActiveEverywhere(kind));
    }

    // Local accesses across many keys should never all require sync.
    var local_hits: usize = 0;
    var key: u64 = 0;
    while (key < 64) : (key += 1) {
        const home = router.homeNodeFor(key, 8);
        if (dist.access(.capability_manager, home, key, .cross_node_read)) {
            local_hits += 1;
        }
    }
    try testing.expectEqual(@as(usize, 64), local_hits);
    try testing.expectEqual(@as(usize, 64), dist.sync_policy.stats.local_fast_path);
    try testing.expectEqual(@as(usize, 0), dist.sync_policy.stats.cross_node_syncs);

    // Now force cross-node access from a fixed local node.
    dist.sync_policy.stats = .{};
    var cross_syncs: usize = 0;
    key = 0;
    while (key < 64) : (key += 1) {
        const home = router.homeNodeFor(key, 8);
        if (home != 0) {
            _ = dist.access(.scheduler, 0, key, .migration);
            cross_syncs += 1;
        }
    }
    try testing.expectEqual(cross_syncs, dist.sync_policy.stats.cross_node_syncs);
}
