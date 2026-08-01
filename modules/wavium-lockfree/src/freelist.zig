const std = @import("std");
const base = @import("ring_buffer.zig");

/// Lock-free freelist over a fixed pool of `capacity` slot indices. The
/// head is a tagged pointer packing a generation counter with the slot
/// index into a single atomic u64 so a CAS can never be fooled by another
/// thread popping and re-pushing the same index between this thread's load
/// and its CAS (the classic ABA problem for lock-free linked structures).
pub fn LockFreeFreelist(comptime capacity: usize) type {
    comptime {
        if (capacity == 0 or capacity >= std.math.maxInt(u32)) {
            @compileError("LockFreeFreelist capacity must be > 0 and < u32 max");
        }
    }
    return struct {
        const Self = @This();
        pub const null_index: u32 = capacity;
        const Tagged = u64;

        next: [capacity]u32,
        head: std.atomic.Value(Tagged) align(base.cache_line_bytes),

        fn pack(index: u32, gen: u32) Tagged {
            return (@as(Tagged, gen) << 32) | @as(Tagged, index);
        }
        fn unpackIndex(tagged: Tagged) u32 {
            return @intCast(tagged & 0xFFFF_FFFF);
        }
        fn unpackGen(tagged: Tagged) u32 {
            return @intCast(tagged >> 32);
        }

        pub fn init() Self {
            var self: Self = .{
                .next = undefined,
                .head = std.atomic.Value(Tagged).init(pack(0, 0)),
            };
            var i: usize = 0;
            while (i < capacity) : (i += 1) {
                self.next[i] = if (i + 1 < capacity) @intCast(i + 1) else null_index;
            }
            return self;
        }

        /// Returns a free slot index, or null if the pool is exhausted.
        pub fn acquire(self: *Self) ?u32 {
            var current = self.head.load(.acquire);
            while (true) {
                const idx = unpackIndex(current);
                if (idx == null_index) return null;
                const gen = unpackGen(current);
                const new_tagged = pack(self.next[idx], gen +% 1);
                if (self.head.cmpxchgWeak(current, new_tagged, .acq_rel, .acquire)) |actual| {
                    current = actual;
                } else {
                    return idx;
                }
            }
        }

        /// Returns `index` to the pool for future `acquire` calls.
        pub fn release(self: *Self, index: u32) void {
            var current = self.head.load(.acquire);
            while (true) {
                self.next[index] = unpackIndex(current);
                const gen = unpackGen(current);
                const new_tagged = pack(index, gen +% 1);
                if (self.head.cmpxchgWeak(current, new_tagged, .acq_rel, .acquire)) |actual| {
                    current = actual;
                } else {
                    return;
                }
            }
        }
    };
}

test "LockFreeFreelist acquires every slot exactly once then reports exhausted" {
    var fl = LockFreeFreelist(4).init();
    var seen: [4]bool = .{ false, false, false, false };

    var i: usize = 0;
    while (i < 4) : (i += 1) {
        const idx = fl.acquire().?;
        try std.testing.expect(!seen[idx]);
        seen[idx] = true;
    }
    try std.testing.expect(fl.acquire() == null);
}

test "LockFreeFreelist released slots become acquirable again" {
    var fl = LockFreeFreelist(2).init();
    const a = fl.acquire().?;
    const b = fl.acquire().?;
    try std.testing.expect(fl.acquire() == null);

    fl.release(a);
    const c = fl.acquire().?;
    try std.testing.expectEqual(a, c);

    fl.release(b);
    fl.release(c);
    try std.testing.expect(fl.acquire() != null);
    try std.testing.expect(fl.acquire() != null);
}
