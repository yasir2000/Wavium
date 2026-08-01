//! Pin table: the core soft/hard affinity registry.
//!
//! - **Hard affinity**: the entity may only ever run on its pinned
//!   core - `allows()` rejects every other core, and the scheduler
//!   integration point (`scheduler.zig`) treats a hard pin as
//!   non-negotiable, overriding even core isolation.
//! - **Soft affinity**: the entity *prefers* its pinned core but may
//!   be placed elsewhere under load - `allows()` always returns true
//!   for a soft pin; the preference is applied by
//!   `latency.chooseLatencyOptimalCore` instead of being enforced here.

const std = @import("std");
const testing = std.testing;
const entity_mod = @import("entity.zig");

pub const CoreId = entity_mod.CoreId;
pub const EntityRef = entity_mod.EntityRef;

pub const AffinityKind = enum { soft, hard };

pub const AffinityError = error{ NotPinned, TableFull };

pub const max_pins = 256;

pub const PinRecord = struct {
    entity: EntityRef,
    cpu: CoreId,
    kind: AffinityKind,
};

pub const PinTable = struct {
    entries: [max_pins]PinRecord,
    count: usize,

    pub fn init() PinTable {
        return .{ .entries = undefined, .count = 0 };
    }

    fn indexOf(self: *const PinTable, entity: EntityRef) ?usize {
        for (self.entries[0..self.count], 0..) |entry, i| {
            if (EntityRef.eql(entry.entity, entity)) return i;
        }
        return null;
    }

    /// Pins `entity` to `cpu` with the given affinity kind. Re-pinning
    /// an already-pinned entity updates it in place (e.g. changing a
    /// soft pin to a hard one, or moving to a different core).
    pub fn pin(self: *PinTable, entity: EntityRef, cpu: CoreId, kind: AffinityKind) AffinityError!void {
        if (self.indexOf(entity)) |i| {
            self.entries[i].cpu = cpu;
            self.entries[i].kind = kind;
            return;
        }
        if (self.count >= max_pins) return AffinityError.TableFull;
        self.entries[self.count] = .{ .entity = entity, .cpu = cpu, .kind = kind };
        self.count += 1;
    }

    pub fn unpin(self: *PinTable, entity: EntityRef) AffinityError!void {
        const i = self.indexOf(entity) orelse return AffinityError.NotPinned;
        self.count -= 1;
        self.entries[i] = self.entries[self.count];
    }

    pub fn query(self: *const PinTable, entity: EntityRef) ?PinRecord {
        const i = self.indexOf(entity) orelse return null;
        return self.entries[i];
    }

    /// Whether `candidate_cpu` is a legal placement for `entity`.
    /// Unpinned entities and soft-pinned entities allow any core;
    /// hard-pinned entities allow only their pinned core.
    pub fn allows(self: *const PinTable, entity: EntityRef, candidate_cpu: CoreId) bool {
        const rec = self.query(entity) orelse return true;
        return switch (rec.kind) {
            .soft => true,
            .hard => candidate_cpu == rec.cpu,
        };
    }
};

test "PinTable pins and queries an entity" {
    var table = PinTable.init();
    const actor = EntityRef{ .kind = .actor, .id = 1 };
    try table.pin(actor, 3, .hard);
    const rec = table.query(actor).?;
    try testing.expectEqual(@as(CoreId, 3), rec.cpu);
    try testing.expectEqual(AffinityKind.hard, rec.kind);
}

test "PinTable.allows enforces hard pins but not soft pins" {
    var table = PinTable.init();
    const hard_actor = EntityRef{ .kind = .actor, .id = 1 };
    const soft_actor = EntityRef{ .kind = .actor, .id = 2 };
    try table.pin(hard_actor, 3, .hard);
    try table.pin(soft_actor, 3, .soft);

    try testing.expect(table.allows(hard_actor, 3));
    try testing.expect(!table.allows(hard_actor, 4));
    try testing.expect(table.allows(soft_actor, 4));
}

test "PinTable.allows returns true for an unpinned entity on any core" {
    var table = PinTable.init();
    const actor = EntityRef{ .kind = .actor, .id = 99 };
    try testing.expect(table.allows(actor, 0));
    try testing.expect(table.allows(actor, 100));
}

test "PinTable unpin removes the entry" {
    var table = PinTable.init();
    const actor = EntityRef{ .kind = .actor, .id = 1 };
    try table.pin(actor, 3, .hard);
    try table.unpin(actor);
    try testing.expect(table.query(actor) == null);
    try testing.expectError(AffinityError.NotPinned, table.unpin(actor));
}

test "PinTable re-pinning an entity updates it in place rather than duplicating" {
    var table = PinTable.init();
    const actor = EntityRef{ .kind = .actor, .id = 1 };
    try table.pin(actor, 3, .soft);
    try table.pin(actor, 5, .hard);
    try testing.expectEqual(@as(usize, 1), table.count);
    try testing.expectEqual(@as(CoreId, 5), table.query(actor).?.cpu);
}
