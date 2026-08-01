//! wavium-topology: complete hardware topology discovery.
//!
//! Detects sockets, NUMA nodes, packages, cores, and logical CPUs
//! (`graph.TopologyGraph`, built by `discovery.discoverTopology`),
//! cache hierarchy sharing domains (`cache_domains`), memory
//! controllers (`memory_controller`), and exposes the whole thing as
//! a topology graph exported to the scheduler and runtime
//! (`export.exportForScheduler` / `export.exportForRuntime`). Supports
//! x86 CPUID, ARM64, and RISC-V discovery methods via the
//! `arch_probe.DiscoveryMethod`/`ArchProbe` seam.

const std = @import("std");
const testing = std.testing;

pub const ids = @import("ids.zig");
pub const arch_probe = @import("arch_probe.zig");
pub const cache_domains = @import("cache_domains.zig");
pub const memory_controller = @import("memory_controller.zig");
pub const graph = @import("graph.zig");
pub const discovery = @import("discovery.zig");
pub const topology_export = @import("export.zig");

pub const DiscoveryMethod = arch_probe.DiscoveryMethod;
pub const ArchProbe = arch_probe.ArchProbe;
pub const TopologyGraph = graph.TopologyGraph;
pub const CacheLevelKind = cache_domains.CacheLevelKind;
pub const MemoryController = memory_controller.MemoryController;
pub const SchedulerCoreHint = topology_export.SchedulerCoreHint;
pub const RuntimeTopologySummary = topology_export.RuntimeTopologySummary;

pub const discoverTopology = discovery.discoverTopology;
pub const exportForScheduler = topology_export.exportForScheduler;
pub const exportForRuntime = topology_export.exportForRuntime;

pub fn moduleName() []const u8 {
    return "wavium-topology";
}

test "moduleName reports the expected module name" {
    try testing.expectEqualStrings("wavium-topology", moduleName());
}

test "end-to-end: discover a 2-socket topology and export it to scheduler and runtime" {
    // Discover: 2 sockets, 1 package/socket, 4 cores/package, SMT2,
    // 1 NUMA node/socket, 1 memory controller/socket.
    var g = try discoverTopology(.x86_cpuid, 2, 1, 4, 2, 1, 1);
    try testing.expectEqual(@as(usize, 16), g.cpuSlice().len);
    try testing.expectEqual(@as(usize, 2), g.socket_count);
    try testing.expectEqual(@as(usize, 2), g.numa_node_count);

    // Cache hierarchy: SMT siblings share L1, whole socket shares L3,
    // but the two sockets do NOT share L3 with each other.
    try testing.expect(g.cache_domains.sharesCache(0, 1, .l1));
    try testing.expect(g.cache_domains.sharesCache(0, 7, .l3));
    try testing.expect(!g.cache_domains.sharesCache(0, 8, .l3));

    // Export to scheduler: every logical CPU gets a hint.
    var hints: [16]SchedulerCoreHint = undefined;
    const hint_count = exportForScheduler(&g, &hints);
    try testing.expectEqual(@as(usize, 16), hint_count);
    try testing.expect(hints[0].numa_node != hints[8].numa_node);

    // Export to runtime: whole-system summary matches the discovered shape.
    const summary = exportForRuntime(&g);
    try testing.expectEqual(@as(usize, 8), summary.core_count);
    try testing.expectEqual(@as(usize, 16), summary.logical_cpu_count);
    try testing.expectEqual(@as(usize, 2), summary.memory_controller_count);
    try testing.expectEqual(DiscoveryMethod.x86_cpuid, summary.method);

    // Memory controllers: capacity is queryable per NUMA node.
    try testing.expect(g.memory_controllers.capacityForNode(0) > 0);
}
