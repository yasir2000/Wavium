const std = @import("std");
const core_mod = @import("core.zig");

pub const NumaNodeId = u8;

pub const CoreTopology = struct {
    id: core_mod.CoreId,
    socket_id: u8,
    numa_node: NumaNodeId,
    smt_sibling: ?core_mod.CoreId,
};

pub const TopologyError = error{
    TooManyCores,
    InvalidGrouping,
};

pub const max_topology_entries = core_mod.max_cores;

pub const Topology = struct {
    entries: [max_topology_entries]CoreTopology,
    count: usize,

    pub fn coreCount(self: Topology) usize {
        return self.count;
    }

    pub fn get(self: Topology, id: core_mod.CoreId) ?CoreTopology {
        for (self.entries[0..self.count]) |e| {
            if (e.id == id) return e;
        }
        return null;
    }

    pub fn socketCount(self: Topology) usize {
        var max_socket: usize = 0;
        var seen_any = false;
        for (self.entries[0..self.count]) |e| {
            seen_any = true;
            if (e.socket_id > max_socket) max_socket = e.socket_id;
        }
        return if (seen_any) max_socket + 1 else 0;
    }
};

/// Deterministically derives a simple topology for `core_count` logical
/// cores, given `cores_per_socket` and `smt_width` (1 = no SMT/hyperthreading).
/// This models what real firmware tables (ACPI MADT on x86_64/ARM64, the
/// device tree or SBI HART list on RISC-V) would report; parsing those
/// tables is out of scope for the runtime-level topology model.
pub fn detect(core_count: usize, cores_per_socket: usize, smt_width: usize) TopologyError!Topology {
    if (core_count > max_topology_entries) return error.TooManyCores;
    if (cores_per_socket == 0 or smt_width == 0) return error.InvalidGrouping;

    var t = Topology{ .entries = undefined, .count = core_count };
    var i: usize = 0;
    while (i < core_count) : (i += 1) {
        const socket_id: u8 = @intCast(i / cores_per_socket);
        const numa_node: NumaNodeId = socket_id;
        const smt_group_start = (i / smt_width) * smt_width;

        var sibling: ?core_mod.CoreId = null;
        if (smt_width > 1) {
            const partner = if (i == smt_group_start) smt_group_start + 1 else smt_group_start;
            if (partner < core_count and partner != i) sibling = @intCast(partner);
        }

        t.entries[i] = .{
            .id = @intCast(i),
            .socket_id = socket_id,
            .numa_node = numa_node,
            .smt_sibling = sibling,
        };
    }
    return t;
}

test "detect assigns sockets by cores_per_socket" {
    const t = try detect(8, 4, 1);
    try std.testing.expectEqual(@as(usize, 8), t.coreCount());
    try std.testing.expectEqual(@as(usize, 2), t.socketCount());

    const c0 = t.get(0) orelse unreachable;
    try std.testing.expectEqual(@as(u8, 0), c0.socket_id);
    const c4 = t.get(4) orelse unreachable;
    try std.testing.expectEqual(@as(u8, 1), c4.socket_id);
    try std.testing.expect(c0.smt_sibling == null);
}

test "detect pairs SMT siblings within a group" {
    const t = try detect(4, 4, 2);
    const c0 = t.get(0) orelse unreachable;
    const c1 = t.get(1) orelse unreachable;
    try std.testing.expectEqual(@as(core_mod.CoreId, 1), c0.smt_sibling.?);
    try std.testing.expectEqual(@as(core_mod.CoreId, 0), c1.smt_sibling.?);
}

test "detect rejects core_count exceeding max and zero grouping" {
    try std.testing.expectError(error.TooManyCores, detect(max_topology_entries + 1, 1, 1));
    try std.testing.expectError(error.InvalidGrouping, detect(4, 0, 1));
    try std.testing.expectError(error.InvalidGrouping, detect(4, 4, 0));
}

test "Topology.get returns null for unknown core" {
    const t = try detect(2, 2, 1);
    try std.testing.expect(t.get(99) == null);
}
