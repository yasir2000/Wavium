//! `padding()` utility - computes and inserts padding bytes so that a
//! value's total size becomes a multiple of the cache-line size. This
//! is the sibling of `alignment.CacheAligned`: alignment controls where
//! a value *starts*, padding controls how much space it *occupies*, so
//! that back-to-back values (e.g. elements of an array) never share a
//! line with their neighbor - the other half of false-sharing
//! prevention.

const hierarchy = @import("hierarchy.zig");

pub const cache_line_bytes = hierarchy.cache_line_bytes;

/// Returns the number of padding bytes required to round `@sizeOf(T)`
/// up to the next multiple of the cache-line size.
pub fn paddingBytes(comptime T: type) usize {
    return paddingFor(@sizeOf(T));
}

/// Returns the padding, in bytes, required to round `size_bytes` up to
/// the next multiple of the cache-line size.
pub fn paddingFor(size_bytes: usize) usize {
    const rem = size_bytes % cache_line_bytes;
    return if (rem == 0) 0 else cache_line_bytes - rem;
}

/// Wraps `T` together with trailing padding so `@sizeOf(Padded(T))` is
/// always a whole multiple of the cache-line size.
pub fn Padded(comptime T: type) type {
    const pad = paddingFor(@sizeOf(T));
    return struct {
        value: T,
        _pad: [pad]u8 = undefined,

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }
    };
}

const testing = @import("std").testing;

test "paddingFor rounds up to the next cache line" {
    try testing.expectEqual(@as(usize, 0), paddingFor(64));
    try testing.expectEqual(@as(usize, 60), paddingFor(4));
    try testing.expectEqual(@as(usize, 28), paddingFor(100));
}

test "paddingBytes matches sizeOf-derived padding" {
    const Small = struct { a: u8 };
    try testing.expectEqual(paddingFor(@sizeOf(Small)), paddingBytes(Small));
}

test "Padded pads size up to a cache-line multiple" {
    const Counter = struct { value: u32 };
    const P = Padded(Counter);
    try testing.expectEqual(@as(usize, 0), @sizeOf(P) % cache_line_bytes);
    try testing.expect(@sizeOf(P) >= cache_line_bytes);

    const p = P.init(.{ .value = 5 });
    try testing.expectEqual(@as(u32, 5), p.value.value);
}

test "Padded array elements do not overlap cache lines" {
    const Flag = struct { set: bool };
    const P = Padded(Flag);
    var arr: [3]P = .{ P.init(.{ .set = false }), P.init(.{ .set = false }), P.init(.{ .set = false }) };
    const stride = @sizeOf(P);
    try testing.expectEqual(@as(usize, 0), stride % cache_line_bytes);

    const base = @intFromPtr(&arr[0]);
    for (&arr, 0..) |*item, i| {
        try testing.expectEqual(base + i * stride, @intFromPtr(item));
    }
}
