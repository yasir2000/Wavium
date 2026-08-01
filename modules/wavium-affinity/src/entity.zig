//! Entity identification: CPU affinity in Wavium is expressed against
//! three kinds of schedulable things (per the prompt: `pin(actor, cpu)`,
//! `pin(component, cpu)`, `pin(runtime_service, cpu)`), unified here
//! under one `EntityRef` so the rest of this module doesn't need three
//! parallel copies of every table.

pub const CoreId = u16;

pub const EntityKind = enum {
    actor,
    component,
    runtime_service,
};

pub const EntityRef = struct {
    kind: EntityKind,
    id: u32,

    pub fn eql(a: EntityRef, b: EntityRef) bool {
        return a.kind == b.kind and a.id == b.id;
    }
};

const std = @import("std");
const testing = std.testing;

test "EntityRef.eql compares both kind and id" {
    const a = EntityRef{ .kind = .actor, .id = 1 };
    const b = EntityRef{ .kind = .actor, .id = 1 };
    const c = EntityRef{ .kind = .component, .id = 1 };
    try testing.expect(EntityRef.eql(a, b));
    try testing.expect(!EntityRef.eql(a, c));
}
