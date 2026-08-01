//! `prefetch()` utility - a thin, ergonomic wrapper around Zig's
//! `@prefetch` builtin (backed by `std.builtin.PrefetchOptions`) for
//! hinting the CPU to pull data into cache ahead of use.

/// Whether the prefetched data will be read or written.
pub const Access = enum { read, write };

/// Temporal locality hint, 0 (no reuse, drop immediately after use) to
/// 3 (high reuse, keep resident as long as possible).
pub const Locality = enum(u2) {
    none = 0,
    low = 1,
    medium = 2,
    high = 3,
};

/// Which cache the prefetch targets.
pub const Target = enum { data, instruction };

/// Issues a prefetch hint for `ptr`. This never faults and never
/// observably changes program behavior - it is purely a performance
/// hint, so it is safe to call on any (even soon-to-be-invalid)
/// pointer within the current scope.
///
/// `access`, `locality`, and `target` must be comptime-known, since
/// `@prefetch`'s options are required to be comptime by the language.
pub fn prefetch(ptr: anytype, comptime access: Access, comptime locality: Locality, comptime target: Target) void {
    @prefetch(ptr, .{
        .rw = if (access == .read) .read else .write,
        .locality = @intFromEnum(locality),
        .cache = if (target == .data) .data else .instruction,
    });
}

/// Convenience wrapper for the overwhelmingly common case: prefetch for
/// an upcoming read, with high temporal locality, from the data cache.
pub fn prefetchRead(ptr: anytype) void {
    prefetch(ptr, .read, .high, .data);
}

/// Convenience wrapper for an upcoming write, with high temporal
/// locality, from the data cache.
pub fn prefetchWrite(ptr: anytype) void {
    prefetch(ptr, .write, .high, .data);
}

const testing = @import("std").testing;

test "prefetch compiles and is callable for reads and writes" {
    var value: u64 = 123;
    prefetch(&value, .read, .high, .data);
    prefetch(&value, .write, .low, .data);
    try testing.expectEqual(@as(u64, 123), value);
}

test "prefetchRead and prefetchWrite convenience wrappers" {
    var arr = [_]u32{ 1, 2, 3, 4 };
    for (&arr) |*item| {
        prefetchRead(item);
    }
    prefetchWrite(&arr[0]);
    try testing.expectEqual(@as(u32, 1), arr[0]);
}

test "prefetch over a slice touches every element via prefetch hints" {
    var buf: [16]u8 = undefined;
    for (&buf, 0..) |*b, i| b.* = @intCast(i);

    var i: usize = 0;
    while (i < buf.len) : (i += 1) {
        prefetchRead(&buf[i]);
    }
    try testing.expectEqual(@as(u8, 0), buf[0]);
    try testing.expectEqual(@as(u8, 15), buf[15]);
}
