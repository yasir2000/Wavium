const std = @import("std");
const cs = @import("core_scheduler.zig");
const affinity = @import("affinity.zig");

pub const MigrationError = error{
    ActorNotFound,
    TargetNotAllowed,
    TargetQueueFull,
};

/// Moves an actor from one core's actor queue to another's, honoring an
/// affinity constraint (e.g. a pinned actor may never migrate off its
/// assigned core). If the target queue is full, the actor is restored to
/// its original core rather than being dropped.
pub fn migrateActor(
    from: *cs.CoreScheduler,
    to: *cs.CoreScheduler,
    actor_id: cs.ActorId,
    aff: affinity.TaskAffinity,
) MigrationError!void {
    if (!aff.allows(to.core_id)) return error.TargetNotAllowed;
    if (!from.actors.remove(actor_id)) return error.ActorNotFound;

    to.submitActor(actor_id) catch {
        from.submitActor(actor_id) catch {};
        return error.TargetQueueFull;
    };
}

test "migrateActor moves an actor between cores" {
    var core0 = cs.CoreScheduler.init(0, 0);
    var core1 = cs.CoreScheduler.init(1, 0);
    try core0.submitActor(7);

    try migrateActor(&core0, &core1, 7, affinity.TaskAffinity.anyCore());

    try std.testing.expect(!core0.actors.remove(7));
    try std.testing.expectEqual(@as(cs.ActorId, 7), core1.actors.pop().?);
}

test "migrateActor rejects an actor pinned away from the target core" {
    var core0 = cs.CoreScheduler.init(0, 0);
    var core1 = cs.CoreScheduler.init(1, 0);
    try core0.submitActor(7);

    const pinned = affinity.TaskAffinity.pinnedTo(0);
    try std.testing.expectError(error.TargetNotAllowed, migrateActor(&core0, &core1, 7, pinned));
    // actor remains on its original core untouched
    try std.testing.expectEqual(@as(cs.ActorId, 7), core0.actors.pop().?);
}

test "migrateActor reports ActorNotFound when the actor isn't on the source core" {
    var core0 = cs.CoreScheduler.init(0, 0);
    var core1 = cs.CoreScheduler.init(1, 0);
    try std.testing.expectError(error.ActorNotFound, migrateActor(&core0, &core1, 99, affinity.TaskAffinity.anyCore()));
}

test "migrateActor restores the actor to its source core if the target is full" {
    var core0 = cs.CoreScheduler.init(0, 0);
    var core1 = cs.CoreScheduler.init(1, 0);
    try core0.submitActor(7);

    var i: usize = 0;
    while (i < cs.actor_capacity) : (i += 1) try core1.submitActor(@intCast(1000 + i));

    try std.testing.expectError(error.TargetQueueFull, migrateActor(&core0, &core1, 7, affinity.TaskAffinity.anyCore()));
    try std.testing.expectEqual(@as(cs.ActorId, 7), core0.actors.pop().?);
}
