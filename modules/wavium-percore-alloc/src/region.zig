//! Region: the coarse-grained backing memory carved out for one core
//! at boot/init time. A `Region` hands out large contiguous spans (via
//! a simple watermark, like `Arena`) that a core then subdivides into
//! its `Arena`/`Slab` backing buffers - keeping every byte a core ever
//! touches within memory that was assigned to it up front, which is
//! what gives the per-core allocator hierarchy its cache locality:
//! nothing a core allocates ever shares a region (and therefore rarely
//! shares a cache line) with another core's memory.

const std = @import("std");
const testing = std.testing;

pub const RegionError = error{ExceedsCapacity};

pub const Region = struct {
    memory: []u8,
    watermark: usize,

    pub fn init(memory: []u8) Region {
        return .{ .memory = memory, .watermark = 0 };
    }

    /// Carves out and returns the next `size` bytes of this region.
    /// Carved spans are never returned to the region individually -
    /// only a full `reset()` reclaims them, mirroring how a real boot
    /// allocator hands fixed spans to per-core subsystems once.
    pub fn carve(self: *Region, size: usize) RegionError![]u8 {
        if (self.watermark + size > self.memory.len) return RegionError.ExceedsCapacity;
        const start = self.watermark;
        self.watermark += size;
        return self.memory[start .. start + size];
    }

    pub fn remaining(self: *const Region) usize {
        return self.memory.len - self.watermark;
    }

    pub fn reset(self: *Region) void {
        self.watermark = 0;
    }
};

test "Region carves sequential non-overlapping spans" {
    var backing: [128]u8 = undefined;
    var region = Region.init(&backing);

    const a = try region.carve(64);
    const b = try region.carve(64);
    try testing.expect(@intFromPtr(a.ptr) != @intFromPtr(b.ptr));
    try testing.expectEqual(@as(usize, 0), region.remaining());
}

test "Region reports ExceedsCapacity once exhausted" {
    var backing: [16]u8 = undefined;
    var region = Region.init(&backing);

    _ = try region.carve(16);
    try testing.expectError(RegionError.ExceedsCapacity, region.carve(1));
}

test "Region reset reclaims the whole span" {
    var backing: [16]u8 = undefined;
    var region = Region.init(&backing);

    _ = try region.carve(16);
    region.reset();
    try testing.expectEqual(@as(usize, 16), region.remaining());
}
