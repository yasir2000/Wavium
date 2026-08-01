//! Accelerator discovery seam: the prompt explicitly says "do not
//! implement hardware-specific code yet; design extensible interfaces
//! and abstractions". `DiscoverFn` is the extension point a future
//! per-vendor/per-bus probe (PCIe capability scan, NPU vendor driver
//! enumeration, SmartNIC firmware query, ...) would implement; this
//! module only defines the contract and a deterministic stub used
//! for testing, mirroring `wavium-topology`'s `ArchProbe`/`ProbeFn`
//! seam (Prompt 26) and `wavium-hal`'s `DriverLifecycle` seam.

const target_kind = @import("target_kind.zig");
const capability = @import("capability.zig");
const target = @import("target.zig");

pub const AcceleratorDescriptor = struct {
    kind: target_kind.ExecutionTargetKind,
    capabilities: capability.CapabilitySet,
};

/// Seam: a real discovery backend fills `out` with every accelerator
/// it finds and returns the count. No implementation lives in this
/// module - only the contract.
pub const DiscoverFn = *const fn (out: []AcceleratorDescriptor) usize;

pub const DiscoveryError = error{RegistryFull};

/// Runs `discover_fn`, then registers every discovered accelerator
/// into `registry` as an `ExecutionTarget`.
pub fn discoverAndRegister(discover_fn: DiscoverFn, registry: *target.TargetRegistry, scratch: []AcceleratorDescriptor) DiscoveryError!usize {
    const found = discover_fn(scratch);
    var registered: usize = 0;
    var i: usize = 0;
    while (i < found) : (i += 1) {
        _ = registry.register(scratch[i].kind, scratch[i].capabilities) catch return DiscoveryError.RegistryFull;
        registered += 1;
    }
    return registered;
}

const testing = @import("std").testing;

fn stubDiscoverNone(out: []AcceleratorDescriptor) usize {
    _ = out;
    return 0;
}

fn stubDiscoverOneGpu(out: []AcceleratorDescriptor) usize {
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.simd_parallel);
    caps.insert(.high_throughput);
    out[0] = .{ .kind = .gpu, .capabilities = caps };
    return 1;
}

test "discoverAndRegister registers nothing when the backend finds nothing" {
    var registry = target.TargetRegistry.init();
    var scratch: [4]AcceleratorDescriptor = undefined;
    const n = try discoverAndRegister(stubDiscoverNone, &registry, &scratch);
    try testing.expectEqual(@as(usize, 0), n);
    try testing.expectEqual(@as(usize, 0), registry.count);
}

test "discoverAndRegister registers a discovered accelerator as a target" {
    var registry = target.TargetRegistry.init();
    var scratch: [4]AcceleratorDescriptor = undefined;
    const n = try discoverAndRegister(stubDiscoverOneGpu, &registry, &scratch);
    try testing.expectEqual(@as(usize, 1), n);
    try testing.expectEqual(@as(usize, 1), registry.count);
    try testing.expectEqual(target_kind.ExecutionTargetKind.gpu, registry.targets[0].kind);
}
