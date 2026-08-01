const std = @import("std");
const cs = @import("core_scheduler.zig");

pub const CoreMask = u64;
pub const max_affinity_cores: u32 = 64;

/// Which cores an actor/task is permitted to run on or migrate to.
pub const TaskAffinity = struct {
    mask: CoreMask,

    pub fn anyCore() TaskAffinity {
        return .{ .mask = ~@as(CoreMask, 0) };
    }

    pub fn pinnedTo(core_id: cs.CoreId) TaskAffinity {
        if (core_id >= max_affinity_cores) return .{ .mask = 0 };
        return .{ .mask = @as(CoreMask, 1) << @intCast(core_id) };
    }

    pub fn withCore(self: TaskAffinity, core_id: cs.CoreId) TaskAffinity {
        if (core_id >= max_affinity_cores) return self;
        return .{ .mask = self.mask | (@as(CoreMask, 1) << @intCast(core_id)) };
    }

    pub fn allows(self: TaskAffinity, core_id: cs.CoreId) bool {
        if (core_id >= max_affinity_cores) return false;
        return (self.mask & (@as(CoreMask, 1) << @intCast(core_id))) != 0;
    }
};

test "anyCore allows every representable core" {
    const aff = TaskAffinity.anyCore();
    try std.testing.expect(aff.allows(0));
    try std.testing.expect(aff.allows(63));
}

test "pinnedTo allows only the specified core" {
    const aff = TaskAffinity.pinnedTo(3);
    try std.testing.expect(aff.allows(3));
    try std.testing.expect(!aff.allows(4));
}

test "withCore extends the allowed set" {
    const aff = TaskAffinity.pinnedTo(0).withCore(2);
    try std.testing.expect(aff.allows(0));
    try std.testing.expect(aff.allows(2));
    try std.testing.expect(!aff.allows(1));
}

test "cores at or beyond max_affinity_cores are never allowed" {
    const aff = TaskAffinity.anyCore();
    try std.testing.expect(!aff.allows(64));
}
