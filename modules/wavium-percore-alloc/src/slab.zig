//! Slab allocator: manages several `Pool`s of different fixed block
//! sizes (size classes) so that an incoming allocation request of any
//! size up to the largest class is rounded up to the nearest class and
//! served from the matching pool - giving good cache locality (blocks
//! of a kind are contiguous within their own pool) without the
//! fragmentation of a general-purpose allocator.

const std = @import("std");
const testing = std.testing;
const pool_mod = @import("pool.zig");

pub const SlabError = error{ NoMatchingClass, ClassExhausted, InvalidBlock };

pub const size_classes = [_]usize{ 16, 32, 64, 128, 256 };
pub const blocks_per_class = 64;

fn classFor(size: usize) SlabError!usize {
    inline for (size_classes, 0..) |cap, i| {
        if (size <= cap) return i;
    }
    return SlabError.NoMatchingClass;
}

pub const Slab = struct {
    pool_16: pool_mod.Pool(16, blocks_per_class),
    pool_32: pool_mod.Pool(32, blocks_per_class),
    pool_64: pool_mod.Pool(64, blocks_per_class),
    pool_128: pool_mod.Pool(128, blocks_per_class),
    pool_256: pool_mod.Pool(256, blocks_per_class),

    pub fn init() Slab {
        return .{
            .pool_16 = pool_mod.Pool(16, blocks_per_class).init(),
            .pool_32 = pool_mod.Pool(32, blocks_per_class).init(),
            .pool_64 = pool_mod.Pool(64, blocks_per_class).init(),
            .pool_128 = pool_mod.Pool(128, blocks_per_class).init(),
            .pool_256 = pool_mod.Pool(256, blocks_per_class).init(),
        };
    }

    /// Rounds `size` up to the nearest size class and serves a block
    /// from that class's pool.
    pub fn alloc(self: *Slab, size: usize) SlabError![]u8 {
        const class = try classFor(size);
        return switch (class) {
            0 => self.pool_16.acquire() catch SlabError.ClassExhausted,
            1 => self.pool_32.acquire() catch SlabError.ClassExhausted,
            2 => self.pool_64.acquire() catch SlabError.ClassExhausted,
            3 => self.pool_128.acquire() catch SlabError.ClassExhausted,
            4 => self.pool_256.acquire() catch SlabError.ClassExhausted,
            else => SlabError.NoMatchingClass,
        };
    }

    /// Recycles `block` (originally allocated for `size`) back into
    /// its size class's pool.
    pub fn free(self: *Slab, size: usize, block: []u8) SlabError!void {
        const class = try classFor(size);
        return switch (class) {
            0 => self.pool_16.release(block) catch SlabError.InvalidBlock,
            1 => self.pool_32.release(block) catch SlabError.InvalidBlock,
            2 => self.pool_64.release(block) catch SlabError.InvalidBlock,
            3 => self.pool_128.release(block) catch SlabError.InvalidBlock,
            4 => self.pool_256.release(block) catch SlabError.InvalidBlock,
            else => SlabError.NoMatchingClass,
        };
    }
};

test "Slab routes allocations to the smallest matching size class" {
    var slab = Slab.init();
    const small = try slab.alloc(10);
    try testing.expectEqual(@as(usize, blocks_per_class - 1), slab.pool_16.available());
    try slab.free(10, small);
    try testing.expectEqual(@as(usize, blocks_per_class), slab.pool_16.available());
}

test "Slab rejects a size larger than every class" {
    var slab = Slab.init();
    try testing.expectError(SlabError.NoMatchingClass, slab.alloc(1024));
}

test "Slab reports ClassExhausted once a class runs out of blocks" {
    var slab = Slab.init();
    var i: usize = 0;
    while (i < blocks_per_class) : (i += 1) _ = try slab.alloc(16);
    try testing.expectError(SlabError.ClassExhausted, slab.alloc(16));
}
