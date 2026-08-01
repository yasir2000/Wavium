const std = @import("std");
const cs = @import("core_scheduler.zig");
const steal = @import("steal.zig");

pub const BalancerError = error{NoImbalance};

/// Minimum ready-queue depth difference between the busiest and idlest
/// core before the balancer will move work.
pub const imbalance_threshold: usize = 2;

const Pair = struct {
    busiest: usize,
    idlest: usize,
};

fn findImbalance(cores: []cs.CoreScheduler, numa_node: ?u8) ?Pair {
    var busiest_idx: ?usize = null;
    var idlest_idx: ?usize = null;
    var busiest_len: usize = 0;
    var idlest_len: usize = std.math.maxInt(usize);

    for (cores, 0..) |*c, i| {
        if (numa_node) |node| {
            if (c.numa_node != node) continue;
        }
        const len = c.readyLen();
        if (busiest_idx == null or len > busiest_len) {
            busiest_idx = i;
            busiest_len = len;
        }
        if (idlest_idx == null or len < idlest_len) {
            idlest_idx = i;
            idlest_len = len;
        }
    }

    const bi = busiest_idx orelse return null;
    const ii = idlest_idx orelse return null;
    if (bi == ii) return null;
    if (busiest_len < idlest_len + imbalance_threshold) return null;
    return .{ .busiest = bi, .idlest = ii };
}

/// Greedy per-core load balancer: prefers moving work between cores in the
/// same NUMA node before falling back to a cross-node steal, since
/// same-node migration/stealing avoids remote-memory-access latency.
pub fn rebalance(cores: []cs.CoreScheduler) BalancerError!usize {
    if (cores.len < 2) return error.NoImbalance;

    for (cores) |c| {
        if (findImbalance(cores, c.numa_node)) |pair| {
            return steal.stealHalf(&cores[pair.busiest], &cores[pair.idlest]) catch error.NoImbalance;
        }
    }

    if (findImbalance(cores, null)) |pair| {
        return steal.stealHalf(&cores[pair.busiest], &cores[pair.idlest]) catch error.NoImbalance;
    }

    return error.NoImbalance;
}

test "rebalance steals from the busiest core into the idlest one on the same NUMA node" {
    var cores = [_]cs.CoreScheduler{
        cs.CoreScheduler.init(0, 0),
        cs.CoreScheduler.init(1, 0),
    };
    var i: usize = 0;
    while (i < 8) : (i += 1) try cores[0].submitTask(.{ .id = @intCast(i) });

    const moved = try rebalance(cores[0..]);
    try std.testing.expectEqual(@as(usize, 4), moved);
    try std.testing.expectEqual(@as(usize, 4), cores[0].readyLen());
    try std.testing.expectEqual(@as(usize, 4), cores[1].readyLen());
}

test "rebalance falls back across NUMA nodes when no same-node imbalance exists" {
    var cores = [_]cs.CoreScheduler{
        cs.CoreScheduler.init(0, 0),
        cs.CoreScheduler.init(1, 1),
    };
    var i: usize = 0;
    while (i < 8) : (i += 1) try cores[0].submitTask(.{ .id = @intCast(i) });

    const moved = try rebalance(cores[0..]);
    try std.testing.expectEqual(@as(usize, 4), moved);
}

test "rebalance reports NoImbalance when queues are already balanced" {
    var cores = [_]cs.CoreScheduler{
        cs.CoreScheduler.init(0, 0),
        cs.CoreScheduler.init(1, 0),
    };
    try cores[0].submitTask(.{ .id = 1 });
    try cores[1].submitTask(.{ .id = 2 });

    try std.testing.expectError(error.NoImbalance, rebalance(cores[0..]));
}
