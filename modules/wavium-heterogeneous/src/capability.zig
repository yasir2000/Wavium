//! "Applications request capabilities, not devices." This is the
//! vocabulary an application uses in a `ComputeRequest` - it never
//! names a `gpu` or `tpu` directly (see `target_kind.zig`), only the
//! kind of computation it needs performed.

const std = @import("std");

pub const ComputeCapability = enum(u4) {
    general_purpose,
    simd_parallel,
    tensor_ops,
    packet_processing,
    low_latency,
    energy_efficient,
    high_throughput,
    reconfigurable_logic,
};

pub const CapabilitySet = std.EnumSet(ComputeCapability);

pub const compute_capabilities = [_]ComputeCapability{
    .general_purpose,
    .simd_parallel,
    .tensor_ops,
    .packet_processing,
    .low_latency,
    .energy_efficient,
    .high_throughput,
    .reconfigurable_logic,
};

pub fn capabilityName(cap: ComputeCapability) []const u8 {
    return switch (cap) {
        .general_purpose => "general_purpose",
        .simd_parallel => "simd_parallel",
        .tensor_ops => "tensor_ops",
        .packet_processing => "packet_processing",
        .low_latency => "low_latency",
        .energy_efficient => "energy_efficient",
        .high_throughput => "high_throughput",
        .reconfigurable_logic => "reconfigurable_logic",
    };
}

const testing = @import("std").testing;

test "compute_capabilities lists every ComputeCapability" {
    try testing.expectEqual(@as(usize, 8), compute_capabilities.len);
}

test "CapabilitySet can express intersection of required capabilities" {
    var a = CapabilitySet.init(.{});
    a.insert(.tensor_ops);
    a.insert(.high_throughput);

    var b = CapabilitySet.init(.{});
    b.insert(.tensor_ops);
    b.insert(.low_latency);

    const shared = a.intersectWith(b);
    try testing.expect(shared.contains(.tensor_ops));
    try testing.expect(!shared.contains(.high_throughput));
}
