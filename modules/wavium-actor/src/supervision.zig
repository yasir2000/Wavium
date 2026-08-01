const std = @import("std");
const actor_ref = @import("actor_ref.zig");

pub const ActorRef = actor_ref.ActorRef;
pub const ActorStatus = actor_ref.ActorStatus;

/// Supervision strategy applied when a child actor fails, per the
/// actor-supervision model (see docs/adr/005-actor-model-choice.md and
/// examples/actor-supervision/).
pub const SupervisionStrategy = enum {
    restart,
    stop,
    escalate,
};

pub const SupervisionError = error{
    UnknownChild,
    AlreadySupervised,
    SupervisorFull,
    RestartLimitExceeded,
    Escalated,
};

pub const ChildSpec = struct {
    actor: ActorRef,
    strategy: SupervisionStrategy,
    max_restarts: u32,
};

const ChildRecord = struct {
    spec: ChildSpec,
    restart_count: u32,
};

pub const MAX_SUPERVISED_CHILDREN: usize = 32;

/// One-for-one supervisor: each child's failure is handled independently
/// according to its own `SupervisionStrategy`, without affecting sibling
/// actors.
pub const Supervisor = struct {
    children: [MAX_SUPERVISED_CHILDREN]ChildRecord,
    count: usize,

    pub fn init() Supervisor {
        return .{ .children = undefined, .count = 0 };
    }

    pub fn addChild(self: *Supervisor, spec: ChildSpec) SupervisionError!void {
        for (self.children[0..self.count]) |record| {
            if (record.spec.actor.id == spec.actor.id) {
                return error.AlreadySupervised;
            }
        }
        if (self.count >= MAX_SUPERVISED_CHILDREN) {
            return error.SupervisorFull;
        }
        self.children[self.count] = .{ .spec = spec, .restart_count = 0 };
        self.count += 1;
    }

    fn findChild(self: *Supervisor, actor_id: u64) SupervisionError!*ChildRecord {
        for (self.children[0..self.count]) |*record| {
            if (record.spec.actor.id == actor_id) return record;
        }
        return error.UnknownChild;
    }

    pub fn childStatus(self: *Supervisor, actor_id: u64) SupervisionError!ActorStatus {
        const record = try self.findChild(actor_id);
        return record.spec.actor.status;
    }

    /// Applies the child's supervision strategy in response to a reported
    /// failure. Returns the actor's new status, or `error.Escalated` if the
    /// strategy is `.escalate` (the caller's own supervisor must then
    /// decide), or `error.RestartLimitExceeded` if a `.restart` child has
    /// exhausted its restart budget (treated as a permanent stop).
    pub fn reportFailure(self: *Supervisor, actor_id: u64) SupervisionError!ActorStatus {
        const record = try self.findChild(actor_id);
        switch (record.spec.strategy) {
            .stop => {
                record.spec.actor.status = .inactive;
                return .inactive;
            },
            .escalate => {
                record.spec.actor.status = .suspended;
                return error.Escalated;
            },
            .restart => {
                if (record.restart_count >= record.spec.max_restarts) {
                    record.spec.actor.status = .inactive;
                    return error.RestartLimitExceeded;
                }
                record.restart_count += 1;
                record.spec.actor.status = .active;
                return .active;
            },
        }
    }

    pub fn restartCount(self: *Supervisor, actor_id: u64) SupervisionError!u32 {
        const record = try self.findChild(actor_id);
        return record.restart_count;
    }
};

test "addChild rejects duplicate actor id" {
    var sup = Supervisor.init();
    const spec = ChildSpec{ .actor = .{ .id = 1, .status = .active }, .strategy = .restart, .max_restarts = 3 };
    try sup.addChild(spec);
    try std.testing.expectError(SupervisionError.AlreadySupervised, sup.addChild(spec));
}

test "restart strategy restarts up to max_restarts then exceeds limit" {
    var sup = Supervisor.init();
    try sup.addChild(.{ .actor = .{ .id = 1, .status = .active }, .strategy = .restart, .max_restarts = 2 });

    try std.testing.expectEqual(ActorStatus.active, try sup.reportFailure(1));
    try std.testing.expectEqual(ActorStatus.active, try sup.reportFailure(1));
    try std.testing.expectError(SupervisionError.RestartLimitExceeded, sup.reportFailure(1));
    try std.testing.expectEqual(ActorStatus.inactive, try sup.childStatus(1));
}

test "stop strategy permanently deactivates the child" {
    var sup = Supervisor.init();
    try sup.addChild(.{ .actor = .{ .id = 2, .status = .active }, .strategy = .stop, .max_restarts = 0 });
    try std.testing.expectEqual(ActorStatus.inactive, try sup.reportFailure(2));
}

test "escalate strategy propagates failure to the caller" {
    var sup = Supervisor.init();
    try sup.addChild(.{ .actor = .{ .id = 3, .status = .active }, .strategy = .escalate, .max_restarts = 0 });
    try std.testing.expectError(SupervisionError.Escalated, sup.reportFailure(3));
    try std.testing.expectEqual(ActorStatus.suspended, try sup.childStatus(3));
}

test "reportFailure on unknown actor id returns UnknownChild" {
    var sup = Supervisor.init();
    try std.testing.expectError(SupervisionError.UnknownChild, sup.reportFailure(999));
}
