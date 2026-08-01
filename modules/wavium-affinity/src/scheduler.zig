//! Scheduler integration: the single entry point a scheduler (e.g.
//! `wavium-coresched`) calls to resolve where an entity should run,
//! combining hard/soft pins, affinity groups, and core isolation into
//! one placement decision. This mirrors the shape of
//! `wavium-coresched`'s existing `affinity.TaskAffinity.allows()`
//! check in its `migration.zig` (Prompt 17) closely enough to be a
//! drop-in replacement there, without this module importing it (kept
//! decoupled per this repository's established convention).

const std = @import("std");
const testing = std.testing;
const entity_mod = @import("entity.zig");
const pin_mod = @import("pin.zig");
const group_mod = @import("group.zig");
const isolation_mod = @import("isolation.zig");
const latency_mod = @import("latency.zig");

pub const CoreId = entity_mod.CoreId;
pub const EntityRef = entity_mod.EntityRef;

pub const ResolveError = error{NoCoresAvailable};

/// Resolves the CPU `entity` should be placed on:
///
///   1. A hard pin always wins, overriding isolation and load - it is
///      an explicit, non-negotiable administrative decision.
///   2. Otherwise, a soft pin's CPU or (failing that) the entity's
///      affinity group's assigned CPU becomes a *preference* fed into
///      latency-optimal placement.
///   3. Latency-optimal placement honors the preference when it is a
///      non-isolated candidate, else picks the least-loaded
///      non-isolated candidate.
pub fn resolveCore(
    pins: *const pin_mod.PinTable,
    groups: *const group_mod.GroupTable,
    isolation: *const isolation_mod.CoreIsolation,
    entity: EntityRef,
    candidates: []const latency_mod.CoreLoad,
) ResolveError!CoreId {
    if (pins.query(entity)) |rec| {
        if (rec.kind == .hard) return rec.cpu;
    }

    var preferred: ?CoreId = null;
    if (pins.query(entity)) |rec| {
        preferred = rec.cpu; // soft pin
    } else if (groups.groupOf(entity)) |gid| {
        preferred = groups.cpuFor(gid);
    }

    return latency_mod.chooseLatencyOptimalCore(candidates, isolation, preferred) catch ResolveError.NoCoresAvailable;
}

test "resolveCore honors a hard pin even onto an isolated core" {
    var pins = pin_mod.PinTable.init();
    var groups = group_mod.GroupTable.init();
    var isolation = isolation_mod.CoreIsolation.init();
    isolation.isolate(3);

    const actor = EntityRef{ .kind = .actor, .id = 1 };
    try pins.pin(actor, 3, .hard);

    const candidates = [_]latency_mod.CoreLoad{.{ .core_id = 0, .load = 0 }};
    const chosen = try resolveCore(&pins, &groups, &isolation, actor, &candidates);
    try testing.expectEqual(@as(CoreId, 3), chosen);
}

test "resolveCore treats a soft pin as a preference, not an override" {
    var pins = pin_mod.PinTable.init();
    var groups = group_mod.GroupTable.init();
    var isolation = isolation_mod.CoreIsolation.init();

    const actor = EntityRef{ .kind = .actor, .id = 1 };
    try pins.pin(actor, 2, .soft);

    const candidates = [_]latency_mod.CoreLoad{ .{ .core_id = 1, .load = 0 }, .{ .core_id = 2, .load = 5 } };
    const chosen = try resolveCore(&pins, &groups, &isolation, actor, &candidates);
    try testing.expectEqual(@as(CoreId, 2), chosen);
}

test "resolveCore falls back to an affinity group's assigned cpu" {
    var pins = pin_mod.PinTable.init();
    var groups = group_mod.GroupTable.init();
    var isolation = isolation_mod.CoreIsolation.init();

    const gid = try groups.createGroup();
    const component = EntityRef{ .kind = .component, .id = 5 };
    try groups.addMember(gid, component);
    try groups.assignCpu(gid, 7);

    const candidates = [_]latency_mod.CoreLoad{ .{ .core_id = 7, .load = 3 }, .{ .core_id = 8, .load = 0 } };
    const chosen = try resolveCore(&pins, &groups, &isolation, component, &candidates);
    try testing.expectEqual(@as(CoreId, 7), chosen);
}

test "resolveCore picks the least-loaded core with no pin or group" {
    var pins = pin_mod.PinTable.init();
    var groups = group_mod.GroupTable.init();
    var isolation = isolation_mod.CoreIsolation.init();

    const service = EntityRef{ .kind = .runtime_service, .id = 9 };
    const candidates = [_]latency_mod.CoreLoad{ .{ .core_id = 0, .load = 9 }, .{ .core_id = 1, .load = 1 } };
    const chosen = try resolveCore(&pins, &groups, &isolation, service, &candidates);
    try testing.expectEqual(@as(CoreId, 1), chosen);
}
