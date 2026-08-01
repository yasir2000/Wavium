//! The application-facing API: `compute.execute()`. Applications
//! request capabilities, never devices - `ExecuteFn` is the seam a
//! real backend (CPU scheduler, GPU driver, NPU runtime, ...) would
//! implement to actually run the work on the chosen target; this
//! module only defines the request/response contract and the
//! target-selection flow.

const target = @import("target.zig");
const capability_mapping = @import("capability_mapping.zig");
const target_kind = @import("target_kind.zig");

pub const ExecutionError = error{
    NoMatchingTarget,
    ExecutionFailed,
};

pub const ExecutionResult = struct {
    target_kind: target_kind.ExecutionTargetKind,
    target_id: target.TargetId,
    succeeded: bool,
};

/// Seam: a real backend executes the opaque `payload` on `chosen`
/// and reports success/failure. No implementation lives here.
pub const ExecuteFn = *const fn (chosen: target.ExecutionTarget, payload: *const anyopaque) bool;

pub const Compute = struct {
    registry: *target.TargetRegistry,
    execute_fn: ExecuteFn,

    const Self = @This();

    pub fn init(registry: *target.TargetRegistry, execute_fn: ExecuteFn) Self {
        return .{ .registry = registry, .execute_fn = execute_fn };
    }

    /// `compute.execute()` - the application only supplies a
    /// `ComputeRequest` (capabilities) and a payload; the runtime
    /// picks "the most appropriate processing unit" via
    /// `capability_mapping.selectTarget` and dispatches through the
    /// `ExecuteFn` seam.
    pub fn execute(self: *Self, request: capability_mapping.ComputeRequest, payload: *const anyopaque) ExecutionError!ExecutionResult {
        const chosen = capability_mapping.selectTarget(self.registry, request) catch return ExecutionError.NoMatchingTarget;
        const ok = self.execute_fn(chosen, payload);
        if (!ok) return ExecutionError.ExecutionFailed;
        return .{ .target_kind = chosen.kind, .target_id = chosen.id, .succeeded = true };
    }
};

const testing = @import("std").testing;
const capability = @import("capability.zig");

fn alwaysSucceeds(chosen: target.ExecutionTarget, payload: *const anyopaque) bool {
    _ = chosen;
    _ = payload;
    return true;
}

fn alwaysFails(chosen: target.ExecutionTarget, payload: *const anyopaque) bool {
    _ = chosen;
    _ = payload;
    return false;
}

test "compute.execute() dispatches to the best-matching target" {
    var registry = target.TargetRegistry.init();
    var npu_caps = capability.CapabilitySet.init(.{});
    npu_caps.insert(.tensor_ops);
    _ = try registry.register(.npu, npu_caps);

    var compute = Compute.init(&registry, alwaysSucceeds);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    var dummy_payload: u32 = 0;
    const result = try compute.execute(.{ .required = required }, &dummy_payload);
    try testing.expectEqual(target_kind.ExecutionTargetKind.npu, result.target_kind);
    try testing.expect(result.succeeded);
}

test "compute.execute() surfaces NoMatchingTarget without calling execute_fn" {
    var registry = target.TargetRegistry.init();
    var compute = Compute.init(&registry, alwaysFails);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.tensor_ops);

    var dummy_payload: u32 = 0;
    try testing.expectError(ExecutionError.NoMatchingTarget, compute.execute(.{ .required = required }, &dummy_payload));
}

test "compute.execute() surfaces ExecutionFailed when the backend fails" {
    var registry = target.TargetRegistry.init();
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.general_purpose);
    _ = try registry.register(.cpu_big, caps);

    var compute = Compute.init(&registry, alwaysFails);

    var required = capability.CapabilitySet.init(.{});
    required.insert(.general_purpose);

    var dummy_payload: u32 = 0;
    try testing.expectError(ExecutionError.ExecutionFailed, compute.execute(.{ .required = required }, &dummy_payload));
}
