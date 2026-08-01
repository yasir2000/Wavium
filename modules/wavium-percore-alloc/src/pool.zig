//! Pool allocator: a fixed-size-block free-list allocator. Every block
//! in the pool is the same size, so `acquire`/`release` are simple
//! index-stack push/pop operations with no fragmentation and no
//! per-allocation metadata beyond a free-index stack - the classic
//! "memory recycling" building block that sits underneath `Slab`.
//!
//! This type is only ever touched by the core that owns it (the owning
//! `CoreAllocator`'s fast path), so none of its operations are atomic:
//! contention-free by construction, not by locking.

const std = @import("std");
const testing = std.testing;

pub const PoolError = error{ PoolExhausted, InvalidBlock };

pub fn Pool(comptime block_size: usize, comptime block_count: usize) type {
    return struct {
        const Self = @This();

        storage: [block_count][block_size]u8,
        free_indices: [block_count]u32,
        free_count: usize,

        pub fn init() Self {
            var self: Self = .{
                .storage = undefined,
                .free_indices = undefined,
                .free_count = block_count,
            };
            for (0..block_count) |i| self.free_indices[i] = @intCast(i);
            return self;
        }

        /// Pops one free block index and returns a slice over it.
        pub fn acquire(self: *Self) PoolError![]u8 {
            if (self.free_count == 0) return PoolError.PoolExhausted;
            self.free_count -= 1;
            const idx = self.free_indices[self.free_count];
            return &self.storage[idx];
        }

        /// Recycles `block` back onto the free-index stack. `block`
        /// must be a slice previously returned by `acquire` on this
        /// same `Pool` instance.
        pub fn release(self: *Self, block: []u8) PoolError!void {
            const base = @intFromPtr(&self.storage[0]);
            const addr = @intFromPtr(block.ptr);
            if (addr < base) return PoolError.InvalidBlock;
            const diff = addr - base;
            if (diff % block_size != 0) return PoolError.InvalidBlock;
            const idx = diff / block_size;
            if (idx >= block_count) return PoolError.InvalidBlock;
            if (self.free_count >= block_count) return PoolError.InvalidBlock;
            self.free_indices[self.free_count] = @intCast(idx);
            self.free_count += 1;
        }

        pub fn available(self: *const Self) usize {
            return self.free_count;
        }
    };
}

test "Pool acquires distinct blocks until exhausted" {
    var pool = Pool(16, 2).init();
    const a = try pool.acquire();
    const b = try pool.acquire();
    try testing.expect(@intFromPtr(a.ptr) != @intFromPtr(b.ptr));
    try testing.expectError(PoolError.PoolExhausted, pool.acquire());
}

test "Pool release recycles a block for reuse" {
    var pool = Pool(16, 1).init();
    const a = try pool.acquire();
    try pool.release(a);
    try testing.expectEqual(@as(usize, 1), pool.available());
    _ = try pool.acquire();
}

test "Pool release rejects a foreign pointer" {
    var pool = Pool(16, 1).init();
    var other: [16]u8 = undefined;
    try testing.expectError(PoolError.InvalidBlock, pool.release(&other));
}
