//! Architecture-specific topology probing.
//!
//! Real topology discovery reads raw per-logical-CPU identity from the
//! hardware: x86 CPUID leaves 0x0B/0x1F (extended topology enumeration),
//! ARM64 `MPIDR_EL1` (Aff0-Aff3 fields encode SMT/core/cluster/socket),
//! and RISC-V hart IDs reported via SBI's Hart State Management (HSM)
//! extension. This module never issues those privileged
//! instructions/calls itself - it only defines the seam
//! (`ProbeFn`), matching this repository's established
//! function-pointer decoupling pattern (`ExecutionBackend`,
//! `DriverLifecycle`, `ArchBackend`, `StartFn`, etc.).

const ids = @import("ids.zig");

/// Which architecture-specific mechanism a given probe uses to
/// enumerate topology.
pub const DiscoveryMethod = enum {
    x86_cpuid,
    arm64_mpidr,
    riscv_hart_sbi,
};

pub const ProbeError = error{ProbeFailed};

/// Raw per-logical-CPU identity, as a real hardware probe would
/// report it, before it's assembled into a full `LogicalCpuDescriptor`.
pub const RawIdentity = struct {
    logical_id: ids.LogicalCpuId,
    core_id: ids.CoreId,
    package_id: ids.PackageId,
    socket_id: ids.SocketId,
    smt_index: u8,
};

pub const ProbeFn = *const fn (logical_id: ids.LogicalCpuId) ProbeError!RawIdentity;

/// Binds a `DiscoveryMethod` to the concrete probe function that
/// implements it on real hardware.
pub const ArchProbe = struct {
    method: DiscoveryMethod,
    probe_fn: ProbeFn,

    pub fn probe(self: ArchProbe, logical_id: ids.LogicalCpuId) ProbeError!RawIdentity {
        return self.probe_fn(logical_id);
    }
};

const testing = @import("std").testing;

fn fakeProbe(logical_id: ids.LogicalCpuId) ProbeError!RawIdentity {
    if (logical_id >= 8) return ProbeError.ProbeFailed;
    return .{
        .logical_id = logical_id,
        .core_id = logical_id / 2,
        .package_id = 0,
        .socket_id = 0,
        .smt_index = @intCast(logical_id % 2),
    };
}

test "ArchProbe dispatches to the bound probe function" {
    const probe = ArchProbe{ .method = .x86_cpuid, .probe_fn = fakeProbe };
    const identity = try probe.probe(3);
    try testing.expectEqual(@as(ids.CoreId, 1), identity.core_id);
    try testing.expectEqual(@as(u8, 1), identity.smt_index);
}

test "ArchProbe surfaces ProbeFailed for an out-of-range logical id" {
    const probe = ArchProbe{ .method = .arm64_mpidr, .probe_fn = fakeProbe };
    try testing.expectError(ProbeError.ProbeFailed, probe.probe(99));
}
