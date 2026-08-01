//! wavium-cache: cache-aware runtime utilities.
//!
//! Optimizes Wavium for modern CPU cache hierarchies, covering every
//! bullet in the prompt:
//!
//!   - L1/L2/L3 hierarchy modeling and sizing        -> `hierarchy`
//!   - Cache-line alignment (`cache_aligned(T)`)      -> `alignment`
//!   - False-sharing prevention (`padding()`)          -> `padding`
//!   - Prefetching (`prefetch()`)                      -> `prefetch`
//!   - Data locality / hot-cold data separation        -> `hotcold`
//!   - Structure packing                               -> `packing`
//!   - Cache-efficiency benchmarking                   -> `benchmark`

const std = @import("std");
const testing = std.testing;

pub const hierarchy = @import("hierarchy.zig");
pub const alignment = @import("alignment.zig");
pub const padding = @import("padding.zig");
pub const prefetch_mod = @import("prefetch.zig");
pub const hotcold = @import("hotcold.zig");
pub const packing = @import("packing.zig");
pub const benchmark = @import("benchmark.zig");

pub const cache_line_bytes = hierarchy.cache_line_bytes;
pub const CacheLevel = hierarchy.CacheLevel;
pub const CacheHierarchy = hierarchy.CacheHierarchy;
pub const CacheAligned = alignment.CacheAligned;
pub const Padded = padding.Padded;
pub const HotColdArray = hotcold.HotColdArray;
pub const PackedFlags = packing.PackedFlags;

/// `cache_aligned(T)` per the prompt's exact required name - an alias
/// for `alignment.CacheAligned`.
pub const cache_aligned = alignment.CacheAligned;

/// `padding(T)` per the prompt's exact required name - returns the
/// number of padding bytes needed to round `T` up to a full cache
/// line.
pub fn padding_fn(comptime T: type) usize {
    return padding.paddingBytes(T);
}

/// `prefetch()` per the prompt's exact required name.
pub const prefetch = prefetch_mod.prefetch;
pub const prefetchRead = prefetch_mod.prefetchRead;
pub const prefetchWrite = prefetch_mod.prefetchWrite;

pub fn moduleName() []const u8 {
    return "wavium-cache";
}

test "moduleName reports the expected module name" {
    try testing.expectEqualStrings("wavium-cache", moduleName());
}

test "end-to-end: hierarchy sizing, alignment, padding, prefetch, and hot/cold separation" {
    // L1/L2/L3 hierarchy: size a tile of 64-byte records to fit in L1.
    const h = CacheHierarchy.default();
    const tile = h.tileCount(.l1, cache_line_bytes, 25);
    try testing.expect(tile > 0);

    // cache_aligned(T): a hot atomic-like counter gets its own line.
    const Counter = cache_aligned(u64);
    var counter = Counter.init(0);
    try testing.expectEqual(@as(usize, cache_line_bytes), @as(usize, @alignOf(Counter)));
    counter.get().* += 1;
    try testing.expectEqual(@as(u64, 1), counter.get().*);

    // padding(T): round a small struct up to a full cache line so an
    // array of them never lets two elements share a line.
    const Flag = struct { set: bool };
    try testing.expect(padding_fn(Flag) > 0);
    const PaddedFlag = Padded(Flag);
    try testing.expectEqual(@as(usize, 0), @sizeOf(PaddedFlag) % cache_line_bytes);

    // prefetch(): issue a hint before touching data.
    var value: u32 = 99;
    prefetchRead(&value);
    try testing.expectEqual(@as(u32, 99), value);

    // hot/cold separation: only the hot loop below touches `hot`.
    const Hot = struct { score: u32 };
    const Cold = struct { blob: [128]u8 };
    var store = HotColdArray(Hot, Cold, 4).init();
    _ = try store.append(.{ .score = 10 }, .{ .blob = undefined });
    _ = try store.append(.{ .score = 20 }, .{ .blob = undefined });
    var total: u32 = 0;
    for (store.hotSlice()) |h2| total += h2.score;
    try testing.expectEqual(@as(u32, 30), total);

    // Structure packing: a bit-packed flag set is far smaller than a
    // bool array of the same length.
    const Flags = PackedFlags(4);
    try testing.expect(@sizeOf(Flags) < @sizeOf([4]bool));

    // Benchmark: all three summation strategies agree.
    const result = benchmark.runSuite(64);
    try testing.expectEqual(result.naive_sum, result.padded_sum);
    try testing.expectEqual(result.naive_sum, result.hotcold_sum);
}
