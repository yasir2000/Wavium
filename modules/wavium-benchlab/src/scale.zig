//! The 8 core-count scale points this prompt requires: 1, 2, 4, 8,
//! 16, 32, 64, 128. Deliberately a fresh, independent list from
//! `wavium-massive-parallel`'s `supported_core_counts` (Prompt 27,
//! which starts at 8 and goes to 1024) - this lab's range starts at
//! 1 CPU (a non-distributed baseline) which that module never models.

pub const core_counts = [_]usize{ 1, 2, 4, 8, 16, 32, 64, 128 };

pub fn isSupportedCoreCount(core_count: usize) bool {
    for (core_counts) |c| {
        if (c == core_count) return true;
    }
    return false;
}

/// floor(log2(n)) for n >= 1, used by the synthetic cost model to
/// derive a mild, deterministic contention penalty that grows slowly
/// as core_count increases.
pub fn log2Floor(n: usize) usize {
    if (n <= 1) return 0;
    var v = n;
    var bits: usize = 0;
    while (v > 1) : (v >>= 1) bits += 1;
    return bits;
}

const testing = @import("std").testing;

test "core_counts lists exactly the 8 required scale points" {
    try testing.expectEqual(@as(usize, 8), core_counts.len);
    try testing.expectEqual(@as(usize, 1), core_counts[0]);
    try testing.expectEqual(@as(usize, 128), core_counts[7]);
}

test "isSupportedCoreCount accepts listed and rejects unlisted values" {
    try testing.expect(isSupportedCoreCount(1));
    try testing.expect(isSupportedCoreCount(128));
    try testing.expect(!isSupportedCoreCount(3));
    try testing.expect(!isSupportedCoreCount(256));
}

test "log2Floor matches expected powers of two" {
    try testing.expectEqual(@as(usize, 0), log2Floor(1));
    try testing.expectEqual(@as(usize, 3), log2Floor(8));
    try testing.expectEqual(@as(usize, 7), log2Floor(128));
}
