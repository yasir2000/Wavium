//! Shared identifier types for hardware topology discovery: sockets,
//! packages, cores, logical CPUs, and NUMA nodes.

pub const SocketId = u16;
pub const PackageId = u16;
pub const CoreId = u16;
pub const LogicalCpuId = u16;
pub const NumaNodeId = u16;

/// A single logical CPU (hardware thread) as placed in the full
/// socket -> package -> core -> logical-CPU hierarchy, plus its NUMA
/// node assignment.
pub const LogicalCpuDescriptor = struct {
    logical_id: LogicalCpuId,
    core_id: CoreId,
    package_id: PackageId,
    socket_id: SocketId,
    numa_node: NumaNodeId,
    /// Index of this hardware thread within its physical core (0 for
    /// the first SMT sibling, 1 for the second, etc.).
    smt_index: u8,
};

const testing = @import("std").testing;

test "LogicalCpuDescriptor stores full hierarchy placement" {
    const cpu = LogicalCpuDescriptor{
        .logical_id = 5,
        .core_id = 2,
        .package_id = 0,
        .socket_id = 0,
        .numa_node = 0,
        .smt_index = 1,
    };
    try testing.expectEqual(@as(LogicalCpuId, 5), cpu.logical_id);
    try testing.expectEqual(@as(u8, 1), cpu.smt_index);
}
