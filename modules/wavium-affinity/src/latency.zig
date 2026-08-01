//! Latency optimization: chooses the best CPU for a placement that
//! has no hard pin. A `preferred` core (from a soft pin or an
//! affinity group) is honored whenever it is a candidate and not
//! isolated - keeping related work co-located minimizes cross-core
//! cache misses and IPI round-trips. Otherwise the least-loaded
//! non-isolated candidate is chosen.

const std = @import("std");
const testing = std.testing;
const entity_mod = @import("entity.zig");
const isolation_mod = @import("isolation.zig");

pub const CoreId = entity_mod.CoreId;

pub const LatencyError = error{NoCoresAvailable};

pub const CoreLoad = struct {
    core_id: CoreId,
    load: usize,
};

pub fn chooseLatencyOptimalCore(
    candidates: []const CoreLoad,
    isolation: *const isolation_mod.CoreIsolation,
    preferred: ?CoreId,
) LatencyError!CoreId {
    if (preferred) |p| {
        for (candidates) |c| {
            if (c.core_id == p and !isolation.isIsolated(p)) return p;
        }
    }

    var best: ?CoreLoad = null;
    for (candidates) |c| {
        if (isolation.isIsolated(c.core_id)) continue;
        if (best == null or c.load < best.?.load) best = c;
    }
    return if (best) |b| b.core_id else LatencyError.NoCoresAvailable;
}

test "chooseLatencyOptimalCore honors a non-isolated preferred core" {
    var isolation = isolation_mod.CoreIsolation.init();
    const candidates = [_]CoreLoad{ .{ .core_id = 0, .load = 1 }, .{ .core_id = 1, .load = 5 } };
    const chosen = try chooseLatencyOptimalCore(&candidates, &isolation, 1);
    try testing.expectEqual(@as(CoreId, 1), chosen);
}

test "chooseLatencyOptimalCore falls back to least-loaded when preferred is isolated" {
    var isolation = isolation_mod.CoreIsolation.init();
    isolation.isolate(1);
    const candidates = [_]CoreLoad{ .{ .core_id = 0, .load = 3 }, .{ .core_id = 1, .load = 0 } };
    const chosen = try chooseLatencyOptimalCore(&candidates, &isolation, 1);
    try testing.expectEqual(@as(CoreId, 0), chosen);
}

test "chooseLatencyOptimalCore picks the least-loaded non-isolated core with no preference" {
    var isolation = isolation_mod.CoreIsolation.init();
    isolation.isolate(0);
    const candidates = [_]CoreLoad{
        .{ .core_id = 0, .load = 0 },
        .{ .core_id = 1, .load = 9 },
        .{ .core_id = 2, .load = 2 },
    };
    const chosen = try chooseLatencyOptimalCore(&candidates, &isolation, null);
    try testing.expectEqual(@as(CoreId, 2), chosen);
}

test "chooseLatencyOptimalCore reports NoCoresAvailable when every candidate is isolated" {
    var isolation = isolation_mod.CoreIsolation.init();
    isolation.isolate(0);
    const candidates = [_]CoreLoad{.{ .core_id = 0, .load = 0 }};
    try testing.expectError(LatencyError.NoCoresAvailable, chooseLatencyOptimalCore(&candidates, &isolation, null));
}
