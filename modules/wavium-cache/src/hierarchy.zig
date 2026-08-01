//! Cache hierarchy descriptions (L1/L2/L3) used for data-locality and
//! blocking/tiling decisions.
//!
//! This module models the "Support: L1, L2, L3" requirement of the
//! cache-aware runtime prompt. Since Wavium is freestanding, real
//! hierarchy detection would come from CPUID / device-tree probing
//! (owned by `wavium-hal`); here we model the data shape plus sane
//! defaults so the rest of the runtime has something concrete to plan
//! against, with an explicit override hook for platforms that can
//! probe real sizes.

/// A single level of the cache hierarchy.
pub const CacheLevel = enum(u2) {
    l1 = 1,
    l2 = 2,
    l3 = 3,
};

/// Size and line-width description of one cache level.
pub const LevelInfo = struct {
    level: CacheLevel,
    /// Total capacity of this cache level, in bytes.
    size_bytes: usize,
    /// Line size for this cache level, in bytes.
    line_bytes: usize,
};

/// Describes an entire L1/L2/L3 hierarchy for a core (or core cluster).
pub const CacheHierarchy = struct {
    l1: LevelInfo,
    l2: LevelInfo,
    l3: LevelInfo,

    /// A conservative, widely-applicable default hierarchy, used when no
    /// platform-specific probe is available. Values reflect common
    /// contemporary desktop/server cores: 32 KiB L1, 256 KiB L2 (private
    /// per core), and 8 MiB L3 (shared).
    pub fn default() CacheHierarchy {
        return .{
            .l1 = .{ .level = .l1, .size_bytes = 32 * 1024, .line_bytes = cache_line_bytes },
            .l2 = .{ .level = .l2, .size_bytes = 256 * 1024, .line_bytes = cache_line_bytes },
            .l3 = .{ .level = .l3, .size_bytes = 8 * 1024 * 1024, .line_bytes = cache_line_bytes },
        };
    }

    /// Constructs a hierarchy from explicit, platform-probed sizes.
    pub fn init(l1_size: usize, l2_size: usize, l3_size: usize) CacheHierarchy {
        return .{
            .l1 = .{ .level = .l1, .size_bytes = l1_size, .line_bytes = cache_line_bytes },
            .l2 = .{ .level = .l2, .size_bytes = l2_size, .line_bytes = cache_line_bytes },
            .l3 = .{ .level = .l3, .size_bytes = l3_size, .line_bytes = cache_line_bytes },
        };
    }

    /// Returns the `LevelInfo` for the requested level.
    pub fn levelInfo(self: CacheHierarchy, level: CacheLevel) LevelInfo {
        return switch (level) {
            .l1 => self.l1,
            .l2 => self.l2,
            .l3 => self.l3,
        };
    }

    /// Returns the number of `line_bytes`-sized lines that fit in the
    /// given level's capacity - useful for sizing blocking/tiling loops
    /// so a working set fits within a specific cache level.
    pub fn linesIn(self: CacheHierarchy, level: CacheLevel) usize {
        const info = self.levelInfo(level);
        return info.size_bytes / info.line_bytes;
    }

    /// Returns the largest power-of-two element count of `element_size`
    /// bytes that comfortably fits (with headroom) inside the given
    /// cache level. This is the core "data locality" helper used to
    /// size blocked/tiled algorithms so hot working sets stay resident.
    pub fn tileCount(self: CacheHierarchy, level: CacheLevel, element_size: usize, headroom_percent: u8) usize {
        const info = self.levelInfo(level);
        const usable = (info.size_bytes * (100 - headroom_percent)) / 100;
        if (element_size == 0 or usable < element_size) return 1;
        var count: usize = 1;
        while (count * 2 * element_size <= usable) : (count *= 2) {}
        return count;
    }
};

/// Cache-line size in bytes. Uniform across all levels on essentially
/// every mainstream architecture Wavium targets.
pub const cache_line_bytes: usize = 64;

const testing = @import("std").testing;

test "default hierarchy has ascending capacities" {
    const h = CacheHierarchy.default();
    try testing.expect(h.l1.size_bytes < h.l2.size_bytes);
    try testing.expect(h.l2.size_bytes < h.l3.size_bytes);
    try testing.expectEqual(cache_line_bytes, h.l1.line_bytes);
}

test "init builds a custom hierarchy" {
    const h = CacheHierarchy.init(48 * 1024, 512 * 1024, 16 * 1024 * 1024);
    try testing.expectEqual(@as(usize, 48 * 1024), h.levelInfo(.l1).size_bytes);
    try testing.expectEqual(@as(usize, 16 * 1024 * 1024), h.levelInfo(.l3).size_bytes);
}

test "linesIn computes line counts" {
    const h = CacheHierarchy.default();
    try testing.expectEqual(h.l1.size_bytes / cache_line_bytes, h.linesIn(.l1));
}

test "tileCount fits within cache capacity with headroom" {
    const h = CacheHierarchy.default();
    const count = h.tileCount(.l1, 64, 25);
    const usable = (h.l1.size_bytes * 75) / 100;
    try testing.expect(count * 64 <= usable);
    // Doubling once more should exceed the usable budget.
    try testing.expect(count * 2 * 64 > usable);
}

test "tileCount handles zero element size and oversized elements" {
    const h = CacheHierarchy.default();
    try testing.expectEqual(@as(usize, 1), h.tileCount(.l1, 0, 0));
    try testing.expectEqual(@as(usize, 1), h.tileCount(.l1, h.l1.size_bytes * 2, 0));
}
