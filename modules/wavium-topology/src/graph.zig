//! `TopologyGraph`: the full discovered hardware topology - every
//! logical CPU's place in the socket -> package -> core -> logical-CPU
//! hierarchy plus its NUMA node, the discovered cache-sharing domains,
//! and the discovered memory controllers. This is the central
//! structure the rest of this module builds and exports.

const ids = @import("ids.zig");
const arch_probe = @import("arch_probe.zig");
const cache_domains = @import("cache_domains.zig");
const memory_controller = @import("memory_controller.zig");

pub const max_cpus = 256;

pub const GraphError = error{TooManyCpus};

pub const TopologyGraph = struct {
    method: arch_probe.DiscoveryMethod,
    cpus: [max_cpus]ids.LogicalCpuDescriptor = undefined,
    cpu_count: usize = 0,
    socket_count: usize = 0,
    package_count: usize = 0,
    core_count: usize = 0,
    numa_node_count: usize = 0,
    cache_domains: cache_domains.CacheDomainTable = cache_domains.CacheDomainTable.init(),
    memory_controllers: memory_controller.MemoryControllerTable = memory_controller.MemoryControllerTable.init(),

    const Self = @This();

    pub fn init(method: arch_probe.DiscoveryMethod) Self {
        return .{ .method = method };
    }

    pub fn addCpu(self: *Self, desc: ids.LogicalCpuDescriptor) GraphError!void {
        if (self.cpu_count >= max_cpus) return GraphError.TooManyCpus;
        self.cpus[self.cpu_count] = desc;
        self.cpu_count += 1;
    }

    pub fn cpuSlice(self: *const Self) []const ids.LogicalCpuDescriptor {
        return self.cpus[0..self.cpu_count];
    }

    /// Finds the descriptor for `logical_id`, if it was discovered.
    pub fn cpu(self: *const Self, logical_id: ids.LogicalCpuId) ?ids.LogicalCpuDescriptor {
        var i: usize = 0;
        while (i < self.cpu_count) : (i += 1) {
            if (self.cpus[i].logical_id == logical_id) return self.cpus[i];
        }
        return null;
    }

    /// Fills `out` with every logical CPU belonging to `numa_node`,
    /// returning the number written.
    pub fn cpusInNumaNode(self: *const Self, numa_node: ids.NumaNodeId, out: []ids.LogicalCpuId) usize {
        var written: usize = 0;
        var i: usize = 0;
        while (i < self.cpu_count and written < out.len) : (i += 1) {
            if (self.cpus[i].numa_node == numa_node) {
                out[written] = self.cpus[i].logical_id;
                written += 1;
            }
        }
        return written;
    }
};

const testing = @import("std").testing;

test "TopologyGraph accumulates logical CPUs and looks them up" {
    var graph = TopologyGraph.init(.x86_cpuid);
    try graph.addCpu(.{ .logical_id = 0, .core_id = 0, .package_id = 0, .socket_id = 0, .numa_node = 0, .smt_index = 0 });
    try graph.addCpu(.{ .logical_id = 1, .core_id = 0, .package_id = 0, .socket_id = 0, .numa_node = 0, .smt_index = 1 });

    try testing.expectEqual(@as(usize, 2), graph.cpuSlice().len);
    const found = graph.cpu(1) orelse unreachable;
    try testing.expectEqual(@as(u8, 1), found.smt_index);
    try testing.expect(graph.cpu(99) == null);
}

test "TopologyGraph.cpusInNumaNode filters by NUMA node" {
    var graph = TopologyGraph.init(.arm64_mpidr);
    try graph.addCpu(.{ .logical_id = 0, .core_id = 0, .package_id = 0, .socket_id = 0, .numa_node = 0, .smt_index = 0 });
    try graph.addCpu(.{ .logical_id = 1, .core_id = 1, .package_id = 0, .socket_id = 1, .numa_node = 1, .smt_index = 0 });

    var out: [4]ids.LogicalCpuId = undefined;
    const n = graph.cpusInNumaNode(1, &out);
    try testing.expectEqual(@as(usize, 1), n);
    try testing.expectEqual(@as(ids.LogicalCpuId, 1), out[0]);
}
