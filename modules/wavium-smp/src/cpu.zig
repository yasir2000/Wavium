const std = @import("std");
const core_mod = @import("core.zig");

/// Runtime-owned CPU affinity mask. One bit per logical core; supports up
/// to 64 cores per mask word (matching the common single-word affinity
/// mask size used by cargo/zig-build-style tooling before per-core
/// allocators are introduced).
pub const AffinityMask = u64;
pub const max_affinity_cores: u32 = 64;

pub const CpuAffinity = struct {
    mask: AffinityMask,

    pub fn none() CpuAffinity {
        return .{ .mask = 0 };
    }

    pub fn all() CpuAffinity {
        return .{ .mask = ~@as(AffinityMask, 0) };
    }

    pub fn withCore(self: CpuAffinity, id: core_mod.CoreId) CpuAffinity {
        if (id >= max_affinity_cores) return self;
        return .{ .mask = self.mask | (@as(AffinityMask, 1) << @intCast(id)) };
    }

    pub fn withoutCore(self: CpuAffinity, id: core_mod.CoreId) CpuAffinity {
        if (id >= max_affinity_cores) return self;
        return .{ .mask = self.mask & ~(@as(AffinityMask, 1) << @intCast(id)) };
    }

    pub fn allows(self: CpuAffinity, id: core_mod.CoreId) bool {
        if (id >= max_affinity_cores) return false;
        return (self.mask & (@as(AffinityMask, 1) << @intCast(id))) != 0;
    }

    pub fn coreCount(self: CpuAffinity) u32 {
        return @popCount(self.mask);
    }
};

test "none and all affinity masks" {
    const none = CpuAffinity.none();
    try std.testing.expectEqual(@as(u32, 0), none.coreCount());
    try std.testing.expect(!none.allows(0));

    const all = CpuAffinity.all();
    try std.testing.expectEqual(@as(u32, 64), all.coreCount());
    try std.testing.expect(all.allows(0));
    try std.testing.expect(all.allows(63));
}

test "withCore and withoutCore toggle membership" {
    var aff = CpuAffinity.none().withCore(2).withCore(5);
    try std.testing.expect(aff.allows(2));
    try std.testing.expect(aff.allows(5));
    try std.testing.expect(!aff.allows(3));
    try std.testing.expectEqual(@as(u32, 2), aff.coreCount());

    aff = aff.withoutCore(2);
    try std.testing.expect(!aff.allows(2));
    try std.testing.expectEqual(@as(u32, 1), aff.coreCount());
}

test "cores at or beyond max_affinity_cores are ignored" {
    const aff = CpuAffinity.none().withCore(64).withCore(1000);
    try std.testing.expectEqual(@as(u32, 0), aff.coreCount());
    try std.testing.expect(!aff.allows(64));
}
