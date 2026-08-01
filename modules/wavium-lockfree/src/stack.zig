const std = @import("std");
const base = @import("ring_buffer.zig");
const freelist_mod = @import("freelist.zig");

/// Lock-free bounded LIFO stack (Treiber-style). Value storage is drawn
/// from a `LockFreeFreelist` slot pool (no allocator involved); the
/// logical LIFO chain uses its own tagged `top` pointer (generation +
/// index) to defeat ABA independently of the freelist's own tagging.
pub fn LockFreeStack(comptime T: type, comptime capacity: usize) type {
    return struct {
        const Self = @This();
        const null_index: u32 = capacity;
        const Tagged = u64;

        fn pack(index: u32, gen: u32) Tagged {
            return (@as(Tagged, gen) << 32) | @as(Tagged, index);
        }
        fn unpackIndex(tagged: Tagged) u32 {
            return @intCast(tagged & 0xFFFF_FFFF);
        }
        fn unpackGen(tagged: Tagged) u32 {
            return @intCast(tagged >> 32);
        }

        values: [capacity]T,
        value_next: [capacity]u32,
        top: std.atomic.Value(Tagged) align(base.cache_line_bytes),
        free: freelist_mod.LockFreeFreelist(capacity),

        pub fn init() Self {
            return .{
                .values = undefined,
                .value_next = undefined,
                .top = std.atomic.Value(Tagged).init(pack(null_index, 0)),
                .free = freelist_mod.LockFreeFreelist(capacity).init(),
            };
        }

        pub fn push(self: *Self, value: T) bool {
            const idx = self.free.acquire() orelse return false;
            self.values[idx] = value;

            var current = self.top.load(.acquire);
            while (true) {
                self.value_next[idx] = unpackIndex(current);
                const gen = unpackGen(current);
                const new_top = pack(idx, gen +% 1);
                if (self.top.cmpxchgWeak(current, new_top, .acq_rel, .acquire)) |actual| {
                    current = actual;
                } else {
                    return true;
                }
            }
        }

        pub fn pop(self: *Self) ?T {
            var current = self.top.load(.acquire);
            while (true) {
                const idx = unpackIndex(current);
                if (idx == null_index) return null;
                const gen = unpackGen(current);
                const next_idx = self.value_next[idx];
                const new_top = pack(next_idx, gen +% 1);
                if (self.top.cmpxchgWeak(current, new_top, .acq_rel, .acquire)) |actual| {
                    current = actual;
                } else {
                    const value = self.values[idx];
                    self.free.release(idx);
                    return value;
                }
            }
        }

        pub fn isEmpty(self: *Self) bool {
            return unpackIndex(self.top.load(.acquire)) == null_index;
        }
    };
}

test "LockFreeStack pops in LIFO order" {
    var s = LockFreeStack(u32, 4).init();
    try std.testing.expect(s.push(1));
    try std.testing.expect(s.push(2));
    try std.testing.expect(s.push(3));

    try std.testing.expectEqual(@as(u32, 3), s.pop().?);
    try std.testing.expectEqual(@as(u32, 2), s.pop().?);
    try std.testing.expectEqual(@as(u32, 1), s.pop().?);
    try std.testing.expect(s.pop() == null);
}

test "LockFreeStack rejects push once its slot pool is exhausted" {
    var s = LockFreeStack(u32, 2).init();
    try std.testing.expect(s.push(1));
    try std.testing.expect(s.push(2));
    try std.testing.expect(!s.push(3));
}

test "LockFreeStack slots are reusable after pop (ABA-safe via generation tagging)" {
    var s = LockFreeStack(u32, 2).init();
    try std.testing.expect(s.push(1));
    try std.testing.expect(s.push(2));
    try std.testing.expectEqual(@as(u32, 2), s.pop().?);
    try std.testing.expect(s.push(3));
    try std.testing.expectEqual(@as(u32, 3), s.pop().?);
    try std.testing.expectEqual(@as(u32, 1), s.pop().?);
    try std.testing.expect(s.isEmpty());
}
