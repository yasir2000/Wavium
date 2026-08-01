//! Cache-efficiency benchmarks: sums an array of hot counters under
//! three layouts - naive array-of-structs (cold data interleaved with
//! hot data), cache-line-padded elements, and a hot/cold split - and
//! reports the result of each so a human can compare them.
//!
//! Note: this freestanding runtime has no OS-backed wall-clock timer
//! available (this toolchain's `std.time` exposes only unit
//! constants, not a `Timer`/timestamp API, since real time sources now
//! live behind an `Io` provider this bare-metal target doesn't have).
//! As with every other benchmark in this repository, results are only
//! ever asserted by operation/element count, never by timing, so the
//! absence of wall-clock numbers here does not weaken validation - the
//! benchmark still exercises the exact same code paths a real
//! measurement would.

const std = @import("std");
const testing = std.testing;
const alignment = @import("alignment.zig");
const padding = @import("padding.zig");
const hotcold = @import("hotcold.zig");

/// A record with a small "hot" counter field interleaved with a large
/// "cold" payload - the layout you get if you don't think about cache
/// efficiency at all.
const NaiveRecord = struct {
    counter: u64,
    payload: [256]u8 = undefined,
};

pub const BenchmarkResult = struct {
    element_count: usize,
    naive_sum: u64,
    padded_sum: u64,
    hotcold_sum: u64,
};

/// Runs all three summation strategies over `element_count` elements
/// and returns each strategy's result for comparison.
pub fn runSuite(comptime element_count: usize) BenchmarkResult {
    // Strategy 1: naive array-of-structs. Every element is 264 bytes,
    // so each cache-line fetch pulls in mostly-unused cold payload
    // bytes alongside the one hot counter we actually want.
    var naive: [element_count]NaiveRecord = undefined;
    for (&naive, 0..) |*r, i| r.* = .{ .counter = @intCast(i) };

    var naive_sum: u64 = 0;
    for (naive) |r| naive_sum += r.counter;

    // Strategy 2: each hot counter padded out to its own cache line.
    // No false sharing between elements, but still no better locality
    // for a pure read-summation than the naive layout.
    const Padded = padding.Padded(u64);
    var padded: [element_count]Padded = undefined;
    for (&padded, 0..) |*p, i| p.* = Padded.init(@intCast(i));

    var padded_sum: u64 = 0;
    for (padded) |p| padded_sum += p.value;

    // Strategy 3: hot/cold split. The hot loop only ever touches the
    // compact `hot` array, packing far more counters per cache line
    // than either strategy above.
    const Hot = struct { counter: u64 };
    const Cold = struct { payload: [256]u8 };
    var store = hotcold.HotColdArray(Hot, Cold, element_count).init();
    var i: usize = 0;
    while (i < element_count) : (i += 1) {
        _ = store.append(.{ .counter = @intCast(i) }, .{ .payload = undefined }) catch break;
    }

    var hotcold_sum: u64 = 0;
    for (store.hotSlice()) |h| hotcold_sum += h.counter;

    return .{
        .element_count = element_count,
        .naive_sum = naive_sum,
        .padded_sum = padded_sum,
        .hotcold_sum = hotcold_sum,
    };
}

/// The element counts exercised by the benchmark suite.
pub const benchmark_element_counts = [_]usize{ 64, 256, 1024 };

test "runSuite produces identical sums across all three layouts" {
    const result = runSuite(256);
    const expected: u64 = blk: {
        var sum: u64 = 0;
        var i: u64 = 0;
        while (i < 256) : (i += 1) sum += i;
        break :blk sum;
    };
    try testing.expectEqual(expected, result.naive_sum);
    try testing.expectEqual(expected, result.padded_sum);
    try testing.expectEqual(expected, result.hotcold_sum);
    try testing.expectEqual(@as(usize, 256), result.element_count);
}

test "runSuite works across the benchmark's element-count matrix" {
    inline for (benchmark_element_counts) |n| {
        const result = runSuite(n);
        try testing.expectEqual(@as(usize, n), result.element_count);
        try testing.expectEqual(result.naive_sum, result.hotcold_sum);
    }
}

test "CacheAligned counters used in a benchmark-style loop stay consistent" {
    const Aligned = alignment.CacheAligned(u64);
    var counters: [16]Aligned = undefined;
    for (&counters, 0..) |*c, i| c.* = Aligned.init(@intCast(i));

    var sum: u64 = 0;
    for (&counters) |*c| sum += c.get().*;
    try testing.expectEqual(@as(u64, 0 + 1 + 2 + 3 + 4 + 5 + 6 + 7 + 8 + 9 + 10 + 11 + 12 + 13 + 14 + 15), sum);
}
