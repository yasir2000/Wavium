//! Cache-hierarchy sharing domains discovered as part of hardware
//! topology: which logical CPUs share a given L1/L2/L3 cache
//! instance. This complements `wavium-cache`'s size/line-width model
//! (Prompt 25) with the topology-discovery question of *which cores*
//! share *which physical cache instance* - information the scheduler
//! needs to keep cooperating actors on cache-sharing cores.

const ids = @import("ids.zig");

pub const CacheLevelKind = enum(u2) {
    l1 = 1,
    l2 = 2,
    l3 = 3,
};

/// One physical cache instance and the bitmask of logical CPUs
/// (`bit N` = logical CPU N) served by it.
pub const CacheDomain = struct {
    level: CacheLevelKind,
    shared_mask: u64,
};

pub const CacheDomainError = error{TooManyDomains};

pub const max_domains = 64;

/// A fixed-capacity table of discovered cache domains across all
/// levels.
pub const CacheDomainTable = struct {
    domains: [max_domains]CacheDomain = undefined,
    count: usize = 0,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn addDomain(self: *Self, level: CacheLevelKind, shared_mask: u64) CacheDomainError!void {
        if (self.count >= max_domains) return CacheDomainError.TooManyDomains;
        self.domains[self.count] = .{ .level = level, .shared_mask = shared_mask };
        self.count += 1;
    }

    /// Returns the domain at `level` that contains `cpu_id`, if any.
    pub fn domainFor(self: *const Self, cpu_id: ids.LogicalCpuId, level: CacheLevelKind) ?CacheDomain {
        const bit = @as(u64, 1) << @intCast(cpu_id);
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            const d = self.domains[i];
            if (d.level == level and (d.shared_mask & bit) != 0) return d;
        }
        return null;
    }

    /// Whether logical CPUs `a` and `b` share the same cache instance
    /// at `level`.
    pub fn sharesCache(self: *const Self, a: ids.LogicalCpuId, b: ids.LogicalCpuId, level: CacheLevelKind) bool {
        const da = self.domainFor(a, level) orelse return false;
        const bit_b = @as(u64, 1) << @intCast(b);
        return (da.shared_mask & bit_b) != 0;
    }

    pub fn len(self: *const Self) usize {
        return self.count;
    }
};

const testing = @import("std").testing;

test "CacheDomainTable tracks per-level sharing" {
    var table = CacheDomainTable.init();
    try table.addDomain(.l1, 0b0000_0011); // cpus 0,1 share L1 (SMT siblings)
    try table.addDomain(.l3, 0b0000_1111); // cpus 0-3 share L3 (whole socket)

    try testing.expect(table.sharesCache(0, 1, .l1));
    try testing.expect(!table.sharesCache(0, 2, .l1));
    try testing.expect(table.sharesCache(1, 3, .l3));
    try testing.expectEqual(@as(usize, 2), table.len());
}

test "CacheDomainTable reports TooManyDomains once full" {
    var table = CacheDomainTable.init();
    var i: usize = 0;
    while (i < max_domains) : (i += 1) {
        try table.addDomain(.l2, 1);
    }
    try testing.expectError(CacheDomainError.TooManyDomains, table.addDomain(.l2, 1));
}
