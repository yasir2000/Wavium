//! `cache_aligned(T)` utility - forces a value of type `T` onto its own
//! cache-line boundary so it never shares a line with unrelated data
//! (false-sharing prevention) and so per-line prefetches pull in only
//! that value's data.

const hierarchy = @import("hierarchy.zig");

pub const cache_line_bytes = hierarchy.cache_line_bytes;

/// Wraps `T` in a struct whose alignment is bumped to the cache-line
/// size. Because a struct's natural alignment is at least the max
/// alignment of its fields, giving `value` an explicit `align(64)`
/// makes every `CacheAligned(T)` instance (standalone, in an array, or
/// embedded in another struct) start on its own cache line.
pub fn CacheAligned(comptime T: type) type {
    return struct {
        value: T align(cache_line_bytes),

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }

        pub fn get(self: *Self) *T {
            return &self.value;
        }

        pub fn getConst(self: *const Self) *const T {
            return &self.value;
        }
    };
}

const testing = @import("std").testing;

test "CacheAligned forces cache-line alignment" {
    const Aligned = CacheAligned(u32);
    try testing.expectEqual(@as(usize, cache_line_bytes), @as(usize, @alignOf(Aligned)));

    var a = Aligned.init(42);
    try testing.expectEqual(@as(u32, 42), a.get().*);
    a.get().* = 7;
    try testing.expectEqual(@as(u32, 7), a.getConst().*);
}

test "CacheAligned array elements each land on separate lines" {
    const Aligned = CacheAligned(u8);
    var arr: [4]Aligned = .{ Aligned.init(1), Aligned.init(2), Aligned.init(3), Aligned.init(4) };

    const base = @intFromPtr(&arr[0]);
    for (&arr, 0..) |*item, i| {
        const addr = @intFromPtr(item);
        try testing.expectEqual(@as(usize, 0), (addr - base) % cache_line_bytes);
        try testing.expectEqual(@as(usize, i * cache_line_bytes), addr - base);
    }
}

test "CacheAligned works with a small struct too" {
    const Counters = struct { hits: u64, misses: u64 };
    const Aligned = CacheAligned(Counters);
    try testing.expect(@alignOf(Aligned) >= cache_line_bytes);

    var c = Aligned.init(.{ .hits = 0, .misses = 0 });
    c.get().hits += 1;
    try testing.expectEqual(@as(u64, 1), c.getConst().hits);
}
