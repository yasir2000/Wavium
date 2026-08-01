//! Deterministic hardware topology discovery.
//!
//! Real discovery would walk x86 CPUID leaves 0x0B/0x1F, ARM64
//! `MPIDR_EL1` affinity fields, or RISC-V hart IDs via SBI HSM (see
//! `arch_probe.zig`) to learn the ACTUAL socket/package/core/SMT
//! placement of each logical CPU. Lacking real hardware here, this
//! builds the exact same `TopologyGraph` shape deterministically from
//! a requested shape - the same "detect() constructs a plausible,
//! consistent topology" approach `wavium-smp`'s `topology.zig` (Prompt
//! 16) and `wavium-numa`'s `node.zig` (Prompt 21) already use - so the
//! rest of the runtime has something concrete to build and test
//! against.

const ids = @import("ids.zig");
const arch_probe = @import("arch_probe.zig");
const cache_domains = @import("cache_domains.zig");
const memory_controller = @import("memory_controller.zig");
const graph_mod = @import("graph.zig");

pub const DiscoveryMethod = arch_probe.DiscoveryMethod;
pub const TopologyGraph = graph_mod.TopologyGraph;

pub const DiscoveryError = graph_mod.GraphError ||
    cache_domains.CacheDomainError ||
    memory_controller.MemoryControllerError ||
    error{TooManyLogicalCpusForCacheMask};

/// Default capacity assumed for each discovered memory controller
/// when the caller has no more specific figure (8 GiB).
pub const default_controller_capacity_bytes: usize = 8 * 1024 * 1024 * 1024;

fn rangeMask(start: usize, end: usize) u64 {
    var mask: u64 = 0;
    var i = start;
    while (i < end) : (i += 1) {
        mask |= @as(u64, 1) << @intCast(i);
    }
    return mask;
}

/// Discovers (deterministically constructs) a full topology graph for
/// `socket_count` sockets, each with `packages_per_socket` packages,
/// each with `cores_per_package` physical cores, each core exposing
/// `smt_width` logical CPUs (hardware threads). NUMA nodes and memory
/// controllers are distributed `numa_nodes_per_socket` /
/// `memory_controllers_per_socket` per socket, round-robin across
/// packages.
///
/// Builds L1 (per-core, shared across a core's own SMT siblings), L2
/// (per-package, shared across every core in a package), and L3
/// (per-socket, shared across every package in a socket) cache
/// domains alongside the CPU hierarchy.
pub fn discoverTopology(
    method: DiscoveryMethod,
    socket_count: usize,
    packages_per_socket: usize,
    cores_per_package: usize,
    smt_width: usize,
    numa_nodes_per_socket: usize,
    memory_controllers_per_socket: usize,
) DiscoveryError!TopologyGraph {
    const total_logical_cpus = socket_count * packages_per_socket * cores_per_package * smt_width;
    if (total_logical_cpus > 64) return DiscoveryError.TooManyLogicalCpusForCacheMask;

    var g = TopologyGraph.init(method);
    g.socket_count = socket_count;
    g.package_count = socket_count * packages_per_socket;
    g.core_count = g.package_count * cores_per_package;
    g.numa_node_count = socket_count * numa_nodes_per_socket;

    var logical_id: usize = 0;
    var package_id: ids.PackageId = 0;
    var core_id: ids.CoreId = 0;

    var socket: usize = 0;
    while (socket < socket_count) : (socket += 1) {
        const socket_start_logical = logical_id;

        var pkg_in_socket: usize = 0;
        while (pkg_in_socket < packages_per_socket) : (pkg_in_socket += 1) {
            const package_start_logical = logical_id;
            const numa_node: ids.NumaNodeId = @intCast(socket * numa_nodes_per_socket + (pkg_in_socket % numa_nodes_per_socket));

            var core_in_pkg: usize = 0;
            while (core_in_pkg < cores_per_package) : (core_in_pkg += 1) {
                const core_start_logical = logical_id;

                var smt: usize = 0;
                while (smt < smt_width) : (smt += 1) {
                    try g.addCpu(.{
                        .logical_id = @intCast(logical_id),
                        .core_id = core_id,
                        .package_id = package_id,
                        .socket_id = @intCast(socket),
                        .numa_node = numa_node,
                        .smt_index = @intCast(smt),
                    });
                    logical_id += 1;
                }
                try g.cache_domains.addDomain(.l1, rangeMask(core_start_logical, logical_id));
                core_id += 1;
            }
            try g.cache_domains.addDomain(.l2, rangeMask(package_start_logical, logical_id));
            package_id += 1;
        }
        try g.cache_domains.addDomain(.l3, rangeMask(socket_start_logical, logical_id));

        var mc: usize = 0;
        while (mc < memory_controllers_per_socket) : (mc += 1) {
            const controller_numa_node: ids.NumaNodeId = @intCast(socket * numa_nodes_per_socket + (mc % numa_nodes_per_socket));
            try g.memory_controllers.add(
                @intCast(socket * memory_controllers_per_socket + mc),
                controller_numa_node,
                default_controller_capacity_bytes,
            );
        }
    }

    return g;
}

const testing = @import("std").testing;

test "discoverTopology builds a consistent single-socket dual-core SMT2 graph" {
    var g = try discoverTopology(.x86_cpuid, 1, 1, 2, 2, 1, 1);
    try testing.expectEqual(@as(usize, 4), g.cpuSlice().len);
    try testing.expectEqual(@as(usize, 1), g.socket_count);
    try testing.expectEqual(@as(usize, 2), g.core_count);

    // Logical CPUs 0 and 1 are SMT siblings on core 0.
    try testing.expect(g.cache_domains.sharesCache(0, 1, .l1));
    try testing.expect(!g.cache_domains.sharesCache(0, 2, .l1));
    // All 4 share the same L3 (single package, single socket).
    try testing.expect(g.cache_domains.sharesCache(0, 3, .l3));
}

test "discoverTopology builds a multi-socket NUMA-aware graph" {
    var g = try discoverTopology(.arm64_mpidr, 2, 1, 4, 1, 1, 1);
    try testing.expectEqual(@as(usize, 8), g.cpuSlice().len);
    try testing.expectEqual(@as(usize, 2), g.numa_node_count);

    const cpu0 = g.cpu(0) orelse unreachable;
    const cpu4 = g.cpu(4) orelse unreachable;
    try testing.expect(cpu0.numa_node != cpu4.numa_node);
    try testing.expectEqual(@as(usize, 2), g.memory_controllers.len());
}

test "discoverTopology rejects shapes with more than 64 logical CPUs" {
    try testing.expectError(
        DiscoveryError.TooManyLogicalCpusForCacheMask,
        discoverTopology(.riscv_hart_sbi, 4, 2, 8, 2, 2, 1),
    );
}
