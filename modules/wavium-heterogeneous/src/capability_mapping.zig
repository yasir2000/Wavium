//! Capability mapping: matches a `ComputeRequest` (capabilities an
//! application needs) against registered `ExecutionTarget`s, without
//! the application ever naming a device kind directly.

const capability = @import("capability.zig");
const target = @import("target.zig");
const target_kind = @import("target_kind.zig");

pub const ComputeRequest = struct {
    required: capability.CapabilitySet,
};

pub const MappingError = error{NoMatchingTarget};

/// Score = number of required capabilities the target advertises.
/// A target that doesn't advertise ALL required capabilities scores
/// 0 (hard requirement, not best-effort).
fn scoreTarget(t: target.ExecutionTarget, required: capability.CapabilitySet) usize {
    if (!t.available) return 0;
    if (!required.subsetOf(t.capabilities)) return 0;
    return required.count();
}

/// Picks the best-matching available target for `request` -
/// "the runtime schedules execution on the most appropriate
/// processing unit" without the caller naming one.
pub fn selectTarget(registry: *const target.TargetRegistry, request: ComputeRequest) MappingError!target.ExecutionTarget {
    var best: ?target.ExecutionTarget = null;
    var best_score: usize = 0;

    for (registry.slice()) |t| {
        const score = scoreTarget(t, request.required);
        if (score > best_score or (score > 0 and best == null)) {
            best = t;
            best_score = score;
        }
    }

    return best orelse MappingError.NoMatchingTarget;
}

const testing = @import("std").testing;

test "selectTarget picks a target that satisfies all required capabilities" {
    var registry = target.TargetRegistry.init();
    var cpu_caps = capability.CapabilitySet.init(.{});
    cpu_caps.insert(.general_purpose);
    _ = try registry.register(.cpu_big, cpu_caps);

    var gpu_caps = capability.CapabilitySet.init(.{});
    gpu_caps.insert(.simd_parallel);
    gpu_caps.insert(.high_throughput);
    _ = try registry.register(.gpu, gpu_caps);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.simd_parallel);

    const chosen = try selectTarget(&registry, .{ .required = required });
    try testing.expectEqual(target_kind.ExecutionTargetKind.gpu, chosen.kind);
}

test "selectTarget returns NoMatchingTarget when nothing qualifies" {
    var registry = target.TargetRegistry.init();
    var cpu_caps = capability.CapabilitySet.init(.{});
    cpu_caps.insert(.general_purpose);
    _ = try registry.register(.cpu_big, cpu_caps);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    try testing.expectError(MappingError.NoMatchingTarget, selectTarget(&registry, .{ .required = required }));
}

test "selectTarget skips unavailable targets" {
    var registry = target.TargetRegistry.init();
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.tensor_ops);
    const id = try registry.register(.npu, caps);
    try registry.setAvailable(id, false);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    try testing.expectError(MappingError.NoMatchingTarget, selectTarget(&registry, .{ .required = required }));
}
