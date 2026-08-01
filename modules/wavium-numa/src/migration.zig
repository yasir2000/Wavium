const std = @import("std");
const node_mod = @import("node.zig");
const stats_mod = @import("statistics.zig");

pub const MigrationError = error{
    SameNode,
    NotWorthwhile,
};

pub const remote_ratio_threshold: f64 = 0.5;

pub const MigrationDecision = struct {
    region_id: u64,
    from_node: node_mod.NumaNodeId,
    to_node: node_mod.NumaNodeId,
};

/// Decides whether a memory region currently homed on `home_node` is
/// worth migrating to `candidate_node` (typically wherever most of the
/// actors accessing it are now running), based on the observed
/// remote-access ratio for `home_node` in `stats`.
pub fn evaluateMigration(
    region_id: u64,
    home_node: node_mod.NumaNodeId,
    candidate_node: node_mod.NumaNodeId,
    stats: *const stats_mod.AccessStatistics,
) MigrationError!MigrationDecision {
    if (home_node == candidate_node) return error.SameNode;
    if (stats.remoteRatio(home_node) < remote_ratio_threshold) return error.NotWorthwhile;
    return .{ .region_id = region_id, .from_node = home_node, .to_node = candidate_node };
}

test "evaluateMigration approves migration once remote access ratio crosses the threshold" {
    var stats = stats_mod.AccessStatistics.init();
    stats.recordAccess(0, 0);
    stats.recordAccess(1, 0);
    stats.recordAccess(1, 0);
    stats.recordAccess(1, 0);

    const decision = try evaluateMigration(42, 0, 1, &stats);
    try std.testing.expectEqual(@as(u64, 42), decision.region_id);
    try std.testing.expectEqual(@as(node_mod.NumaNodeId, 0), decision.from_node);
    try std.testing.expectEqual(@as(node_mod.NumaNodeId, 1), decision.to_node);
}

test "evaluateMigration rejects migration when accesses are mostly local" {
    var stats = stats_mod.AccessStatistics.init();
    stats.recordAccess(0, 0);
    stats.recordAccess(0, 0);
    stats.recordAccess(1, 0);

    try std.testing.expectError(error.NotWorthwhile, evaluateMigration(1, 0, 1, &stats));
}

test "evaluateMigration rejects migrating a region to its own home node" {
    const stats = stats_mod.AccessStatistics.init();
    try std.testing.expectError(error.SameNode, evaluateMigration(1, 0, 0, &stats));
}
