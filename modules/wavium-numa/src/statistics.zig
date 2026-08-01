const std = @import("std");
const node_mod = @import("node.zig");

pub const max_tracked_nodes = node_mod.max_nodes;

/// Tracks, per NUMA node, how many memory accesses to data homed on that
/// node came from a core also on that node ("local") versus from a core
/// on a different node ("remote") - the remote-access statistics feeding
/// migration.zig's decisions and useful as a scheduler hint.
pub const AccessStatistics = struct {
    local_accesses: [max_tracked_nodes]u64,
    remote_accesses: [max_tracked_nodes]u64,

    pub fn init() AccessStatistics {
        var self: AccessStatistics = .{
            .local_accesses = undefined,
            .remote_accesses = undefined,
        };
        for (&self.local_accesses) |*v| v.* = 0;
        for (&self.remote_accesses) |*v| v.* = 0;
        return self;
    }

    /// Records one access to memory homed on `home_node`, originating
    /// from a core on `accessing_node`.
    pub fn recordAccess(self: *AccessStatistics, accessing_node: node_mod.NumaNodeId, home_node: node_mod.NumaNodeId) void {
        if (accessing_node == home_node) {
            self.local_accesses[home_node] += 1;
        } else {
            self.remote_accesses[home_node] += 1;
        }
    }

    /// Fraction of accesses to `home_node`'s memory that came from a
    /// remote node, in `[0.0, 1.0]`. Returns 0.0 if there have been no
    /// accesses recorded yet.
    pub fn remoteRatio(self: *const AccessStatistics, home_node: node_mod.NumaNodeId) f64 {
        const local = self.local_accesses[home_node];
        const remote = self.remote_accesses[home_node];
        const total = local + remote;
        if (total == 0) return 0.0;
        return @as(f64, @floatFromInt(remote)) / @as(f64, @floatFromInt(total));
    }
};

test "recordAccess separates local from remote accesses per node" {
    var stats = AccessStatistics.init();
    stats.recordAccess(0, 0); // local
    stats.recordAccess(1, 0); // remote
    stats.recordAccess(1, 0); // remote

    try std.testing.expectEqual(@as(u64, 1), stats.local_accesses[0]);
    try std.testing.expectEqual(@as(u64, 2), stats.remote_accesses[0]);
}

test "remoteRatio computes the fraction of remote accesses" {
    var stats = AccessStatistics.init();
    stats.recordAccess(0, 0);
    stats.recordAccess(1, 0);
    stats.recordAccess(1, 0);
    stats.recordAccess(1, 0);

    try std.testing.expectApproxEqAbs(@as(f64, 0.75), stats.remoteRatio(0), 0.0001);
}

test "remoteRatio is zero for a node with no recorded accesses" {
    const stats = AccessStatistics.init();
    try std.testing.expectEqual(@as(f64, 0.0), stats.remoteRatio(2));
}
