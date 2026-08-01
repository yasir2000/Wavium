const std = @import("std");

/// NUMA-aware execution: node detection with a distance matrix
/// (node.zig), actor placement honoring local-memory preference and
/// scheduler hints (placement.zig), memory-region migration decisions
/// driven by observed remote-access ratios (migration.zig,
/// statistics.zig), and a NUMA-aware allocation seam that prefers the
/// local node before falling back to the nearest remaining one
/// (allocator.zig). Integrates with the scheduler/memory manager/actor
/// runtime via plain data (NumaNodeId) and function-pointer seams rather
/// than direct imports, matching this codebase's decoupling convention.
pub fn moduleName() []const u8 {
    return "wavium-numa";
}

pub const node = @import("node.zig");
pub const placement = @import("placement.zig");
pub const migration = @import("migration.zig");
pub const allocator = @import("allocator.zig");
pub const statistics = @import("statistics.zig");

test "moduleName" {
    try std.testing.expectEqualStrings("wavium-numa", moduleName());
}

fn fakeAlloc(node_id: node.NumaNodeId, _: usize) ?u64 {
    return @as(u64, node_id) + 1;
}

test "end-to-end: detect topology, place an actor, allocate locally, then evaluate migration" {
    const topo = try node.detect(2, 4, 1 << 30);

    // Scheduler hint / local memory preference picks node 1 explicitly.
    const hint = placement.PlacementHint{ .preferred_node = 1 };
    const loads = [_]placement.NodeLoad{
        .{ .node_id = 0, .actor_count = 0 },
        .{ .node_id = 1, .actor_count = 10 },
    };
    const chosen = try placement.chooseNode(hint, loads[0..]);
    try std.testing.expectEqual(@as(node.NumaNodeId, 1), chosen);

    // NUMA-aware allocation prefers the actor's home node.
    const alloc = allocator.NodeAllocator{ .topology = &topo, .alloc_fn = fakeAlloc };
    const handle = try alloc.allocateOn(chosen, 4096);
    try std.testing.expectEqual(@as(u64, 2), handle);

    // Remote access statistics accumulate as other nodes touch this
    // region, eventually making migration worthwhile.
    var stats = statistics.AccessStatistics.init();
    stats.recordAccess(chosen, chosen);
    stats.recordAccess(0, chosen);
    stats.recordAccess(0, chosen);

    const decision = try migration.evaluateMigration(handle, chosen, 0, &stats);
    try std.testing.expectEqual(chosen, decision.from_node);
    try std.testing.expectEqual(@as(node.NumaNodeId, 0), decision.to_node);
}
