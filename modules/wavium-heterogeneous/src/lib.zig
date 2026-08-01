//! wavium-heterogeneous: generic execution-target abstraction for
//! future heterogeneous hardware (Big.LITTLE CPUs, GPUs, NPUs, DPUs,
//! SmartNICs, FPGAs, AI accelerators, TPUs). Applications request
//! capabilities via `compute.execute()`, never devices - the runtime
//! schedules execution on the most appropriate registered target.
//!
//! Deliberately contains NO hardware-specific code (per the prompt's
//! explicit "do not implement hardware-specific code yet" constraint)
//! - every integration point is a function-pointer seam
//! (`DiscoverFn`, `ExecuteFn`, `MigrateFn`), consistent with this
//! repo's decoupling convention.

pub const target_kind = @import("target_kind.zig");
pub const capability = @import("capability.zig");
pub const target = @import("target.zig");
pub const discovery = @import("discovery.zig");
pub const capability_mapping = @import("capability_mapping.zig");
pub const compute = @import("compute.zig");
pub const migration = @import("migration.zig");

pub const ExecutionTargetKind = target_kind.ExecutionTargetKind;
pub const ComputeCapability = capability.ComputeCapability;
pub const ExecutionTarget = target.ExecutionTarget;
pub const TargetRegistry = target.TargetRegistry;
pub const ComputeRequest = capability_mapping.ComputeRequest;
pub const Compute = compute.Compute;
pub const MigrationPlan = migration.MigrationPlan;

pub fn moduleName() []const u8 {
    return "wavium-heterogeneous";
}

const testing = @import("std").testing;

fn integrationExecuteFn(chosen: ExecutionTarget, payload: *const anyopaque) bool {
    _ = chosen;
    _ = payload;
    return true;
}

fn integrationMigrateFn(plan: MigrationPlan, payload: *const anyopaque) bool {
    _ = plan;
    _ = payload;
    return true;
}

test "moduleName" {
    try testing.expectEqualStrings("wavium-heterogeneous", moduleName());
}

test "end-to-end: register heterogeneous targets, execute by capability, then migrate" {
    var registry = TargetRegistry.init();

    var gp = capability.CapabilitySet.init(.{});
    gp.insert(.general_purpose);
    const cpu_big_id = try registry.register(.cpu_big, gp);

    var simd = capability.CapabilitySet.init(.{});
    simd.insert(.simd_parallel);
    simd.insert(.high_throughput);
    _ = try registry.register(.gpu, simd);

    var tensor = capability.CapabilitySet.init(.{});
    tensor.insert(.tensor_ops);
    const npu_id = try registry.register(.npu, tensor);

    var comp = Compute.init(&registry, integrationExecuteFn);

    var required_tensor = capability.CapabilitySet.init(.{});
    required_tensor.insert(.tensor_ops);
    var payload: u32 = 0;
    const result = try comp.execute(.{ .required = required_tensor }, &payload);
    try testing.expectEqual(ExecutionTargetKind.npu, result.target_kind);

    // Simulate the NPU going away and migrating execution elsewhere.
    // (There's no alternative tensor_ops target, so add one first.)
    var tensor2 = capability.CapabilitySet.init(.{});
    tensor2.insert(.tensor_ops);
    _ = try registry.register(.ai_accelerator, tensor2);

    try registry.setAvailable(npu_id, false);
    const from = try registry.find(npu_id);
    const plan = try migration.planAndMigrate(&registry, from, .{ .required = required_tensor }, .target_unavailable, integrationMigrateFn, &payload);
    try testing.expectEqual(ExecutionTargetKind.ai_accelerator, plan.to.kind);

    _ = cpu_big_id;
}
