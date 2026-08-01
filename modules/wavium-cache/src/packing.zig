//! Structure packing utilities: diagnostics for compiler-inserted
//! padding inside a struct's layout, plus a bit-packed flag-set helper
//! for shrinking hot structures so more of them fit per cache line.

const std = @import("std");

/// Sum of the sizes of `T`'s fields, ignoring any padding the compiler
/// inserts between them.
pub fn fieldSizeSum(comptime T: type) usize {
    const info = @typeInfo(T).@"struct";
    var total: usize = 0;
    inline for (info.field_types) |field_type| {
        total += @sizeOf(field_type);
    }
    return total;
}

/// Bytes of padding present in `T`'s actual layout, i.e. the gap
/// between `@sizeOf(T)` and the sum of its fields' sizes. A non-zero
/// result signals a structure-packing opportunity: reordering fields
/// from largest-alignment to smallest typically eliminates it.
pub fn paddingWaste(comptime T: type) usize {
    const sum = fieldSizeSum(T);
    const total = @sizeOf(T);
    return if (total > sum) total - sum else 0;
}

/// A densely bit-packed set of `n` boolean flags, stored in the
/// smallest unsigned integer that holds them (1 bit each) instead of
/// one byte/word per flag - a direct application of structure packing
/// to keep hot flag data compact.
pub fn PackedFlags(comptime n: u16) type {
    return packed struct {
        bits: @Int(.unsigned, n) = 0,

        const Self = @This();
        const Bits = @Int(.unsigned, n);

        pub fn set(self: *Self, index: usize, value: bool) void {
            const mask: Bits = @as(Bits, 1) << @intCast(index);
            if (value) {
                self.bits |= mask;
            } else {
                self.bits &= ~mask;
            }
        }

        pub fn get(self: Self, index: usize) bool {
            const mask: Bits = @as(Bits, 1) << @intCast(index);
            return (self.bits & mask) != 0;
        }

        pub fn count() usize {
            return n;
        }
    };
}

const testing = std.testing;

test "fieldSizeSum sums field sizes without padding" {
    const T = struct { a: u8, b: u32, c: u16 };
    try testing.expectEqual(@as(usize, 1 + 4 + 2), fieldSizeSum(T));
}

test "paddingWaste detects compiler-inserted padding" {
    const Wasteful = struct { a: u8, b: u32, c: u16 };
    try testing.expect(paddingWaste(Wasteful) > 0);

    const Tight = packed struct { a: u8, b: u8, c: u8, d: u8 };
    try testing.expectEqual(@as(usize, 0), paddingWaste(Tight));
}

test "PackedFlags is far smaller than a bool array" {
    const F = PackedFlags(8);
    try testing.expect(@sizeOf(F) < @sizeOf([8]bool));

    var flags = F{};
    flags.set(0, true);
    flags.set(7, true);
    try testing.expect(flags.get(0));
    try testing.expect(!flags.get(1));
    try testing.expect(flags.get(7));

    flags.set(0, false);
    try testing.expect(!flags.get(0));
}

test "PackedFlags reports its bit count" {
    const F = PackedFlags(16);
    try testing.expectEqual(@as(usize, 16), F.count());
}
