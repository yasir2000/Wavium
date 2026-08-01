//! Execution migration: moving an in-flight computation from one
//! execution target to another (e.g. a CPU falls back to running
//! tensor ops after an NPU becomes unavailable, or work moves onto a
//! newly-discovered accelerator). Only the contract is defined here -
//! `MigrateFn` is the seam a real backend would implement to actually
//! serialize/transfer execution state, matching this repo's seam
//! convention (`ExecutionBackend`, `SyncFn`, `AllocFn`/`FreeFn`, ...).

const target = @import("target.zig");
const capability_mapping = @import("capability_mapping.zig");

pub const MigrationReason = enum {
    target_unavailable,
    better_target_discovered,
    load_rebalance,
    capability_downgrade,
};

pub const MigrationPlan = struct {
    from: target.ExecutionTarget,
    to: target.ExecutionTarget,
    reason: MigrationReason,
};

pub const MigrationError = error{
    NoAlternativeTarget,
    MigrationFailed,
};

/// Seam: transfers whatever execution state `payload` represents
/// from `plan.from` to `plan.to`. Returns `true` on success.
pub const MigrateFn = *const fn (plan: MigrationPlan, payload: *const anyopaque) bool;

/// Finds a replacement target satisfying the same `request` as the
/// one currently running on `from`, then invokes `migrate_fn`.
pub fn planAndMigrate(
    registry: *const target.TargetRegistry,
    from: target.ExecutionTarget,
    request: capability_mapping.ComputeRequest,
    reason: MigrationReason,
    migrate_fn: MigrateFn,
    payload: *const anyopaque,
) MigrationError!MigrationPlan {
    const to = capability_mapping.selectTarget(registry, request) catch return MigrationError.NoAlternativeTarget;
    const plan = MigrationPlan{ .from = from, .to = to, .reason = reason };

    const ok = migrate_fn(plan, payload);
    if (!ok) return MigrationError.MigrationFailed;
    return plan;
}

const testing = @import("std").testing;
const capability = @import("capability.zig");
const target_kind = @import("target_kind.zig");

fn migrateSucceeds(plan: MigrationPlan, payload: *const anyopaque) bool {
    _ = plan;
    _ = payload;
    return true;
}

fn migrateFails(plan: MigrationPlan, payload: *const anyopaque) bool {
    _ = plan;
    _ = payload;
    return false;
}

test "planAndMigrate finds a replacement target and succeeds" {
    var registry = target.TargetRegistry.init();
    var cpu_caps = capability.CapabilitySet.init(.{});
    cpu_caps.insert(.tensor_ops);
    const npu_id = try registry.register(.npu, cpu_caps);
    _ = try registry.register(.cpu_big, cpu_caps);

    const from = try registry.find(npu_id);
    try registry.setAvailable(npu_id, false);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    var dummy_payload: u32 = 0;
    const plan = try planAndMigrate(&registry, from, .{ .required = required }, .target_unavailable, migrateSucceeds, &dummy_payload);
    try testing.expectEqual(target_kind.ExecutionTargetKind.cpu_big, plan.to.kind);
}

test "planAndMigrate reports NoAlternativeTarget when nothing else qualifies" {
    var registry = target.TargetRegistry.init();
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.tensor_ops);
    const npu_id = try registry.register(.npu, caps);
    const from = try registry.find(npu_id);
    try registry.setAvailable(npu_id, false);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    var dummy_payload: u32 = 0;
    try testing.expectError(MigrationError.NoAlternativeTarget, planAndMigrate(&registry, from, .{ .required = required }, .target_unavailable, migrateSucceeds, &dummy_payload));
}

test "planAndMigrate reports MigrationFailed when the backend fails" {
    var registry = target.TargetRegistry.init();
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.tensor_ops);
    const id1 = try registry.register(.npu, caps);
    _ = try registry.register(.cpu_big, caps);

    const from = try registry.find(id1);
    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    var dummy_payload: u32 = 0;
    try testing.expectError(MigrationError.MigrationFailed, planAndMigrate(&registry, from, .{ .required = required }, .load_rebalance, migrateFails, &dummy_payload));
}
