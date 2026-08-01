const std = @import("std");
const ownership = @import("ownership.zig");

pub const CapabilityMask = u64;

/// Describes an actor for placement/distribution purposes: its capability
/// set (which of up to 64 capabilities it holds) and whether it is pinned
/// to a specific core (in which case load balancing must never move it).
pub const ActorDescriptor = struct {
    id: ownership.ActorId,
    capabilities: CapabilityMask,
    pinned_core: ?ownership.CoreId,

    pub fn hasCapability(self: ActorDescriptor, capability_bit: u6) bool {
        return (self.capabilities & (@as(CapabilityMask, 1) << capability_bit)) != 0;
    }
};

pub const CoreLoad = struct {
    core_id: ownership.CoreId,
    actor_count: usize,
};

pub const DistributionError = error{NoCoresAvailable};

/// Chooses the target core for an actor: its pinned core if pinned,
/// otherwise the least-loaded core from `loads`.
pub fn chooseCore(descriptor: ActorDescriptor, loads: []const CoreLoad) DistributionError!ownership.CoreId {
    if (descriptor.pinned_core) |pinned| return pinned;
    if (loads.len == 0) return error.NoCoresAvailable;

    var best = loads[0];
    for (loads[1..]) |load| {
        if (load.actor_count < best.actor_count) best = load;
    }
    return best.core_id;
}

test "chooseCore picks the least-loaded core for an unpinned actor" {
    const descriptor = ActorDescriptor{ .id = 1, .capabilities = 0, .pinned_core = null };
    const loads = [_]CoreLoad{
        .{ .core_id = 0, .actor_count = 5 },
        .{ .core_id = 1, .actor_count = 2 },
        .{ .core_id = 2, .actor_count = 9 },
    };
    try std.testing.expectEqual(@as(ownership.CoreId, 1), try chooseCore(descriptor, loads[0..]));
}

test "chooseCore always returns the pinned core, ignoring load" {
    const descriptor = ActorDescriptor{ .id = 1, .capabilities = 0, .pinned_core = 4 };
    const loads = [_]CoreLoad{
        .{ .core_id = 0, .actor_count = 0 },
        .{ .core_id = 4, .actor_count = 99 },
    };
    try std.testing.expectEqual(@as(ownership.CoreId, 4), try chooseCore(descriptor, loads[0..]));
}

test "chooseCore reports NoCoresAvailable when the load list is empty" {
    const descriptor = ActorDescriptor{ .id = 1, .capabilities = 0, .pinned_core = null };
    try std.testing.expectError(error.NoCoresAvailable, chooseCore(descriptor, &.{}));
}

test "ActorDescriptor.hasCapability reflects the capability bitmask" {
    const descriptor = ActorDescriptor{ .id = 1, .capabilities = (1 << 3), .pinned_core = null };
    try std.testing.expect(descriptor.hasCapability(3));
    try std.testing.expect(!descriptor.hasCapability(4));
}
