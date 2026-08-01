//! Scale tiers and hierarchical fan-out grouping for the massive
//! parallel runtime.
//!
//! The prompt requires Wavium to scale across 8/16/32/64/128/256/512/
//! 1024 logical CPUs with "minimal synchronization". A flat design
//! where every core communicates with every other core (or worse,
//! with one central coordinator) degrades badly past a few dozen
//! cores. This file defines the supported scale tiers and a
//! hierarchical grouping function so higher-level aggregation (e.g.
//! load reporting, rebalancing) only ever needs to synchronize within
//! a small local group (~sqrt(core_count) peers) plus one level up,
//! never O(core_count) or O(core_count^2) participants.

pub const supported_core_counts = [_]usize{ 8, 16, 32, 64, 128, 256, 512, 1024 };

pub fn isSupportedScale(core_count: usize) bool {
    for (supported_core_counts) |n| {
        if (n == core_count) return true;
    }
    return false;
}

/// Number of hierarchical fan-out groups to split `core_count` cores
/// into, so each group has roughly `groupCountFor(core_count)` peers
/// too (a balanced two-level tree). Uses an integer square root so
/// grouping stays a pure, allocation-free computation.
pub fn groupCountFor(core_count: usize) usize {
    if (core_count <= 1) return 1;
    var root: usize = 1;
    while (root * root < core_count) : (root += 1) {}
    return root;
}

/// Which group (0-based) a given core belongs to, for the grouping
/// produced by `groupCountFor`.
pub fn groupOf(core_id: usize, core_count: usize) usize {
    const groups = groupCountFor(core_count);
    const group_size = (core_count + groups - 1) / groups;
    return core_id / group_size;
}

const testing = @import("std").testing;

test "isSupportedScale accepts every listed tier and rejects others" {
    for (supported_core_counts) |n| {
        try testing.expect(isSupportedScale(n));
    }
    try testing.expect(!isSupportedScale(7));
    try testing.expect(!isSupportedScale(100));
}

test "groupCountFor grows sub-linearly with core_count" {
    try testing.expectEqual(@as(usize, 3), groupCountFor(8));
    try testing.expectEqual(@as(usize, 32), groupCountFor(1024));
    // 1024 cores split across 32 groups keeps each group's fan-out
    // small (~32 peers), not 1024.
    try testing.expect(groupCountFor(1024) < 1024);
}

test "groupOf distributes cores evenly across groups" {
    // 64 cores, groupCountFor(64) == 8 groups of 8.
    try testing.expectEqual(@as(usize, 0), groupOf(0, 64));
    try testing.expectEqual(@as(usize, 0), groupOf(7, 64));
    try testing.expectEqual(@as(usize, 1), groupOf(8, 64));
    try testing.expectEqual(@as(usize, 7), groupOf(63, 64));
}
