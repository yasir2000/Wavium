const std = @import("std");

/// Cache-line size assumed for cache-aware layout helpers. 64 bytes covers
/// the common case for x86_64, aarch64, and riscv64 targets.
pub const CACHE_LINE_SIZE: usize = 64;

/// Wraps a value so it is aligned to a cache line, preventing false sharing
/// when placed in per-core arrays. This is the Zig compile-time abstraction
/// pattern requested for atomic/cache-aware runtime primitives.
pub fn CacheAligned(comptime T: type) type {
    return struct {
        value: T align(CACHE_LINE_SIZE),

        const Self = @This();

        pub fn init(value: T) Self {
            return .{ .value = value };
        }
    };
}

/// Thin wrapper around `std.atomic.Value` documenting the intended memory
/// ordering defaults for runtime counters shared across cores.
pub fn Counter(comptime T: type) type {
    return struct {
        inner: std.atomic.Value(T),

        const Self = @This();

        pub fn init(initial: T) Self {
            return .{ .inner = std.atomic.Value(T).init(initial) };
        }

        pub fn load(self: *const Self) T {
            return self.inner.load(.acquire);
        }

        pub fn store(self: *Self, value: T) void {
            self.inner.store(value, .release);
        }

        pub fn fetchAdd(self: *Self, delta: T) T {
            return self.inner.fetchAdd(delta, .acq_rel);
        }
    };
}
