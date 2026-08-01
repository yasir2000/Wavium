const std = @import("std");

/// Atomic bitmap over `bit_count` bits, backed by an array of atomic u64
/// words. Bit operations use `fetchOr`/`fetchAnd` (single atomic RMW, no
/// CAS loop needed) so setting/clearing/testing is lock-free and wait-free.
pub fn AtomicBitmap(comptime bit_count: usize) type {
    comptime {
        if (bit_count == 0) @compileError("AtomicBitmap bit_count must be > 0");
    }
    const word_bits = 64;
    const word_count = (bit_count + word_bits - 1) / word_bits;

    return struct {
        const Self = @This();

        words: [word_count]std.atomic.Value(u64),

        pub fn init() Self {
            var self: Self = .{ .words = undefined };
            for (&self.words) |*w| w.* = std.atomic.Value(u64).init(0);
            return self;
        }

        pub fn set(self: *Self, bit: usize) void {
            const word_idx = bit / word_bits;
            const bit_idx: u6 = @intCast(bit % word_bits);
            _ = self.words[word_idx].fetchOr(@as(u64, 1) << bit_idx, .acq_rel);
        }

        pub fn clear(self: *Self, bit: usize) void {
            const word_idx = bit / word_bits;
            const bit_idx: u6 = @intCast(bit % word_bits);
            _ = self.words[word_idx].fetchAnd(~(@as(u64, 1) << bit_idx), .acq_rel);
        }

        pub fn isSet(self: *Self, bit: usize) bool {
            const word_idx = bit / word_bits;
            const bit_idx: u6 = @intCast(bit % word_bits);
            return (self.words[word_idx].load(.acquire) & (@as(u64, 1) << bit_idx)) != 0;
        }

        /// Atomically sets a bit and reports whether it was already set,
        /// i.e. a lock-free "claim this slot" primitive.
        pub fn testAndSet(self: *Self, bit: usize) bool {
            const word_idx = bit / word_bits;
            const bit_idx: u6 = @intCast(bit % word_bits);
            const mask = @as(u64, 1) << bit_idx;
            const old = self.words[word_idx].fetchOr(mask, .acq_rel);
            return (old & mask) != 0;
        }

        pub fn popCount(self: *Self) usize {
            var total: usize = 0;
            for (&self.words) |*w| total += @popCount(w.load(.acquire));
            return total;
        }

        /// Returns the index of the first clear (zero) bit, or null if
        /// every bit up to `bit_count` is set.
        pub fn findFirstClear(self: *Self) ?usize {
            for (&self.words, 0..) |*w, i| {
                const val = w.load(.acquire);
                if (val != std.math.maxInt(u64)) {
                    const inverted = ~val;
                    const bit_in_word = @ctz(inverted);
                    const global_bit = i * word_bits + bit_in_word;
                    if (global_bit < bit_count) return global_bit;
                }
            }
            return null;
        }
    };
}

test "set/clear/isSet round trip" {
    var bm = AtomicBitmap(128).init();
    try std.testing.expect(!bm.isSet(70));
    bm.set(70);
    try std.testing.expect(bm.isSet(70));
    bm.clear(70);
    try std.testing.expect(!bm.isSet(70));
}

test "testAndSet reports prior state and claims the bit" {
    var bm = AtomicBitmap(64).init();
    try std.testing.expect(!bm.testAndSet(3));
    try std.testing.expect(bm.testAndSet(3));
    try std.testing.expect(bm.isSet(3));
}

test "popCount counts set bits across multiple words" {
    var bm = AtomicBitmap(128).init();
    bm.set(0);
    bm.set(63);
    bm.set(64);
    bm.set(127);
    try std.testing.expectEqual(@as(usize, 4), bm.popCount());
}

test "findFirstClear finds the lowest unset bit, honoring bit_count" {
    var bm = AtomicBitmap(70).init();
    var i: usize = 0;
    while (i < 70) : (i += 1) bm.set(i);
    try std.testing.expect(bm.findFirstClear() == null);

    bm.clear(65);
    try std.testing.expectEqual(@as(usize, 65), bm.findFirstClear().?);
}
