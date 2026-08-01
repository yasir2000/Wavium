//! Exports a discovered `TopologyGraph` into the plain, decoupled
//! shapes the scheduler and the rest of the runtime need - per the
//! prompt's explicit "Export topology to scheduler and runtime"
//! requirement. As with every other cross-module seam in this
//! repository, these are plain data (no function pointers needed
//! here, since exporting is a one-shot data transform rather than an
//! ongoing callback), so `wavium-coresched`/`wavium-smp` and other
//! consumers can accept them without this module importing them back.

const ids = @import("ids.zig");
const arch_probe = @import("arch_probe.zig");
const graph_mod = @import("graph.zig");
const cache_domains = @import("cache_domains.zig");

/// One scheduler-facing hint per logical CPU: its NUMA node (for
/// memory-locality-aware placement) and which L3 cache domain it
/// belongs to (for cache-locality-aware placement of cooperating
/// actors), matching the kind of input `wavium-coresched`'s balancer
/// and `wavium-numa`'s placement logic already consume.
pub const SchedulerCoreHint = struct {
    logical_cpu: ids.LogicalCpuId,
    numa_node: ids.NumaNodeId,
    l3_domain_mask: u64,
};

/// Fills `out` with one hint per discovered logical CPU, returning the
/// number written (capped at `out.len`).
pub fn exportForScheduler(g: *const graph_mod.TopologyGraph, out: []SchedulerCoreHint) usize {
    var written: usize = 0;
    for (g.cpuSlice()) |cpu| {
        if (written >= out.len) break;
        const domain = g.cache_domains.domainFor(cpu.logical_id, .l3);
        out[written] = .{
            .logical_cpu = cpu.logical_id,
            .numa_node = cpu.numa_node,
            .l3_domain_mask = if (domain) |d| d.shared_mask else 0,
        };
        written += 1;
    }
    return written;
}

/// A coarse, whole-system summary the runtime uses for capacity
/// planning and reporting (e.g. "how many logical CPUs / NUMA nodes /
/// memory controllers does this machine have").
pub const RuntimeTopologySummary = struct {
    method: arch_probe.DiscoveryMethod,
    socket_count: usize,
    package_count: usize,
    core_count: usize,
    logical_cpu_count: usize,
    numa_node_count: usize,
    memory_controller_count: usize,
    total_memory_bytes: usize,
};

pub fn exportForRuntime(g: *const graph_mod.TopologyGraph) RuntimeTopologySummary {
    var total_memory: usize = 0;
    var node: ids.NumaNodeId = 0;
    while (node < g.numa_node_count) : (node += 1) {
        total_memory += g.memory_controllers.capacityForNode(node);
    }

    return .{
        .method = g.method,
        .socket_count = g.socket_count,
        .package_count = g.package_count,
        .core_count = g.core_count,
        .logical_cpu_count = g.cpu_count,
        .numa_node_count = g.numa_node_count,
        .memory_controller_count = g.memory_controllers.len(),
        .total_memory_bytes = total_memory,
    };
}

const testing = @import("std").testing;
const discovery = @import("discovery.zig");

test "exportForScheduler produces one hint per logical CPU" {
    var g = try discovery.discoverTopology(.x86_cpuid, 1, 1, 2, 2, 1, 1);
    var hints: [8]SchedulerCoreHint = undefined;
    const n = exportForScheduler(&g, &hints);
    try testing.expectEqual(@as(usize, 4), n);
    try testing.expectEqual(@as(ids.NumaNodeId, 0), hints[0].numa_node);
    try testing.expect(hints[0].l3_domain_mask != 0);
}

test "exportForRuntime summarizes socket/core/memory counts" {
    var g = try discovery.discoverTopology(.arm64_mpidr, 2, 1, 4, 1, 1, 1);
    const summary = exportForRuntime(&g);
    try testing.expectEqual(@as(usize, 2), summary.socket_count);
    try testing.expectEqual(@as(usize, 8), summary.core_count);
    try testing.expectEqual(@as(usize, 8), summary.logical_cpu_count);
    try testing.expectEqual(@as(usize, 2), summary.memory_controller_count);
    try testing.expect(summary.total_memory_bytes > 0);
}
