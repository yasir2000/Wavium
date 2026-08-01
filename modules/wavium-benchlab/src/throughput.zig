//! Throughput sample data: operations completed per synthetic tick
//! budget. A "throughput graph" is the series of these samples across
//! the 8 core-count scale points (see `report.zig`'s markdown table
//! and the Mermaid xychart companion diagram).

pub const ThroughputSample = struct {
    operations: u64,
    tick_budget: u64,

    const Self = @This();

    /// Operations per tick, scaled by 1000 to stay in integer math
    /// (avoids floating point entirely, matching this repo's
    /// preference for deterministic integer arithmetic in
    /// benchmarks).
    pub fn opsPerThousandTicks(self: Self) u64 {
        if (self.tick_budget == 0) return 0;
        return (self.operations * 1000) / self.tick_budget;
    }
};

const testing = @import("std").testing;

test "opsPerThousandTicks scales operations by the tick budget" {
    const sample = ThroughputSample{ .operations = 200, .tick_budget = 100 };
    try testing.expectEqual(@as(u64, 2000), sample.opsPerThousandTicks());
}

test "opsPerThousandTicks is 0 for a zero tick budget" {
    const sample = ThroughputSample{ .operations = 5, .tick_budget = 0 };
    try testing.expectEqual(@as(u64, 0), sample.opsPerThousandTicks());
}
