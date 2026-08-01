//! An `ExecutionTarget` is a registered, capability-advertising
//! processing unit instance. `TargetRegistry` is the generic
//! execution-target abstraction the prompt requires - it has no
//! hardware-specific code (no CPU/GPU/NPU driver logic), only a
//! fixed-capacity table of advertised capabilities per target.

const target_kind = @import("target_kind.zig");
const capability = @import("capability.zig");

pub const TargetId = u32;
pub const max_targets = 64;

pub const ExecutionTarget = struct {
    id: TargetId,
    kind: target_kind.ExecutionTargetKind,
    capabilities: capability.CapabilitySet,
    available: bool = true,
};

pub const TargetError = error{
    RegistryFull,
    TargetNotFound,
};

pub const TargetRegistry = struct {
    targets: [max_targets]ExecutionTarget = undefined,
    count: usize = 0,
    next_id: TargetId = 0,

    const Self = @This();

    pub fn init() Self {
        return .{ .targets = undefined, .count = 0, .next_id = 0 };
    }

    pub fn register(self: *Self, kind: target_kind.ExecutionTargetKind, capabilities: capability.CapabilitySet) TargetError!TargetId {
        if (self.count >= max_targets) return TargetError.RegistryFull;
        const id = self.next_id;
        self.targets[self.count] = .{ .id = id, .kind = kind, .capabilities = capabilities };
        self.count += 1;
        self.next_id += 1;
        return id;
    }

    pub fn find(self: *const Self, id: TargetId) TargetError!ExecutionTarget {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.targets[i].id == id) return self.targets[i];
        }
        return TargetError.TargetNotFound;
    }

    pub fn setAvailable(self: *Self, id: TargetId, available: bool) TargetError!void {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.targets[i].id == id) {
                self.targets[i].available = available;
                return;
            }
        }
        return TargetError.TargetNotFound;
    }

    pub fn slice(self: *const Self) []const ExecutionTarget {
        return self.targets[0..self.count];
    }
};

const testing = @import("std").testing;

test "register assigns increasing target ids" {
    var registry = TargetRegistry.init();
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.general_purpose);

    const id0 = try registry.register(.cpu_big, caps);
    const id1 = try registry.register(.cpu_little, caps);
    try testing.expectEqual(@as(TargetId, 0), id0);
    try testing.expectEqual(@as(TargetId, 1), id1);
    try testing.expectEqual(@as(usize, 2), registry.count);
}

test "find returns TargetNotFound for an unregistered id" {
    const registry = TargetRegistry.init();
    try testing.expectError(TargetError.TargetNotFound, registry.find(42));
}

test "setAvailable toggles a target's availability" {
    var registry = TargetRegistry.init();
    var caps = capability.CapabilitySet.init(.{});
    caps.insert(.tensor_ops);
    const id = try registry.register(.npu, caps);

    try registry.setAvailable(id, false);
    const t = try registry.find(id);
    try testing.expect(!t.available);
}
