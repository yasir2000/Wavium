//! wavium-affinity: CPU affinity management for actors, components,
//! and runtime services.
//!
//! Provides the prompt's exact required API shape:
//!
//!   pinActor(table, actor_id, cpu, kind)
//!   pinComponent(table, component_id, cpu, kind)
//!   pinRuntimeService(table, service_id, cpu, kind)
//!
//! plus soft/hard affinity (`pin.AffinityKind`), affinity groups
//! (`group.GroupTable`), core isolation (`isolation.CoreIsolation`),
//! latency optimization (`latency.chooseLatencyOptimalCore`), and the
//! scheduler integration point (`scheduler.resolveCore`).

const std = @import("std");
const testing = std.testing;

pub const entity = @import("entity.zig");
pub const pin = @import("pin.zig");
pub const group = @import("group.zig");
pub const isolation = @import("isolation.zig");
pub const latency = @import("latency.zig");
pub const scheduler = @import("scheduler.zig");

pub const EntityKind = entity.EntityKind;
pub const EntityRef = entity.EntityRef;
pub const CoreId = entity.CoreId;
pub const AffinityKind = pin.AffinityKind;
pub const PinTable = pin.PinTable;
pub const GroupTable = group.GroupTable;
pub const CoreIsolation = isolation.CoreIsolation;

pub fn moduleName() []const u8 {
    return "wavium-affinity";
}

/// Pins an actor to `cpu`, per the prompt's `pin(actor, cpu)`.
pub fn pinActor(table: *PinTable, actor_id: u32, cpu: CoreId, kind: AffinityKind) pin.AffinityError!void {
    try table.pin(.{ .kind = .actor, .id = actor_id }, cpu, kind);
}

/// Pins a component to `cpu`, per the prompt's `pin(component, cpu)`.
pub fn pinComponent(table: *PinTable, component_id: u32, cpu: CoreId, kind: AffinityKind) pin.AffinityError!void {
    try table.pin(.{ .kind = .component, .id = component_id }, cpu, kind);
}

/// Pins a runtime service to `cpu`, per the prompt's
/// `pin(runtime_service, cpu)`.
pub fn pinRuntimeService(table: *PinTable, service_id: u32, cpu: CoreId, kind: AffinityKind) pin.AffinityError!void {
    try table.pin(.{ .kind = .runtime_service, .id = service_id }, cpu, kind);
}

test "moduleName reports the expected module name" {
    try testing.expectEqualStrings("wavium-affinity", moduleName());
}

test "end-to-end: pin actor/component/runtime_service, group co-location, isolation, and scheduler resolution" {
    var table = PinTable.init();
    var groups = GroupTable.init();
    var core_isolation = CoreIsolation.init();

    // pin(actor, cpu) - hard affinity always wins.
    try pinActor(&table, 1, 2, .hard);
    // pin(component, cpu) - soft affinity is just a preference.
    try pinComponent(&table, 10, 3, .soft);
    // pin(runtime_service, cpu) - also supported directly.
    try pinRuntimeService(&table, 100, 4, .hard);

    // Isolate core 5 for a latency-sensitive group.
    core_isolation.isolate(5);

    const gid = try groups.createGroup();
    const worker_a = EntityRef{ .kind = .actor, .id = 20 };
    const worker_b = EntityRef{ .kind = .actor, .id = 21 };
    try groups.addMember(gid, worker_a);
    try groups.addMember(gid, worker_b);
    try groups.assignCpu(gid, 6);

    const candidates = [_]latency.CoreLoad{
        .{ .core_id = 2, .load = 1 },
        .{ .core_id = 3, .load = 1 },
        .{ .core_id = 5, .load = 0 },
        .{ .core_id = 6, .load = 4 },
    };

    // Hard-pinned actor always resolves to its pinned core.
    const actor_ref = EntityRef{ .kind = .actor, .id = 1 };
    try testing.expectEqual(@as(CoreId, 2), try scheduler.resolveCore(&table, &groups, &core_isolation, actor_ref, &candidates));

    // Group members resolve to the group's assigned cpu even though
    // another candidate is less loaded, since co-location is
    // preferred for latency.
    try testing.expectEqual(@as(CoreId, 6), try scheduler.resolveCore(&table, &groups, &core_isolation, worker_a, &candidates));
    try testing.expectEqual(@as(CoreId, 6), try scheduler.resolveCore(&table, &groups, &core_isolation, worker_b, &candidates));

    // An entity with no pin and no group avoids the isolated core (5)
    // even though it has the lowest load, and picks the next best.
    const unpinned = EntityRef{ .kind = .runtime_service, .id = 999 };
    const chosen = try scheduler.resolveCore(&table, &groups, &core_isolation, unpinned, &candidates);
    try testing.expect(chosen != 5);
}
