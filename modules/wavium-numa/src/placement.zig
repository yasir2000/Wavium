const std = @import("std");
const node_mod = @import("node.zig");

/// A placement hint: an explicit `preferred_node` acts as both "local
/// memory preference" for an actor's home node and a scheduler hint (the
/// scheduler should try to run the actor's work on that node's cores).
pub const PlacementHint = struct {
    preferred_node: ?node_mod.NumaNodeId,
};

pub const NodeLoad = struct {
    node_id: node_mod.NumaNodeId,
    actor_count: usize,
};

pub const PlacementError = error{NoNodesAvailable};

/// Chooses a NUMA node to place an actor on: honors `preferred_node` when
/// set, otherwise picks the least-loaded node from `loads`.
pub fn chooseNode(hint: PlacementHint, loads: []const NodeLoad) PlacementError!node_mod.NumaNodeId {
    if (hint.preferred_node) |preferred| return preferred;
    if (loads.len == 0) return error.NoNodesAvailable;

    var best = loads[0];
    for (loads[1..]) |load| {
        if (load.actor_count < best.actor_count) best = load;
    }
    return best.node_id;
}

test "chooseNode honors an explicit preferred node regardless of load" {
    const hint = PlacementHint{ .preferred_node = 3 };
    const loads = [_]NodeLoad{.{ .node_id = 0, .actor_count = 0 }};
    try std.testing.expectEqual(@as(node_mod.NumaNodeId, 3), try chooseNode(hint, loads[0..]));
}

test "chooseNode picks the least-loaded node when no preference is given" {
    const hint = PlacementHint{ .preferred_node = null };
    const loads = [_]NodeLoad{
        .{ .node_id = 0, .actor_count = 8 },
        .{ .node_id = 1, .actor_count = 2 },
    };
    try std.testing.expectEqual(@as(node_mod.NumaNodeId, 1), try chooseNode(hint, loads[0..]));
}

test "chooseNode reports NoNodesAvailable when unhinted and loads is empty" {
    const hint = PlacementHint{ .preferred_node = null };
    try std.testing.expectError(error.NoNodesAvailable, chooseNode(hint, &.{}));
}
