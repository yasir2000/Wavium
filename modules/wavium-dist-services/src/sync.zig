//! "Synchronize only when necessary": same-node access to a
//! distributed service instance is always a local, sync-free fast
//! path. Cross-node access is the only case that ever invokes the
//! (caller-supplied) synchronization mechanism - e.g. an IPI message
//! (`wavium-ipi`), a barrier, or a remote-procedure call. This module
//! stays decoupled from those transports via a function-pointer seam.

const instance_table = @import("instance_table.zig");

pub const NodeId = instance_table.NodeId;

pub const SyncReason = enum {
    cross_node_read,
    cross_node_write,
    migration,
    capability_revocation,
};

/// Seam: the actual cross-node reconciliation mechanism. Returns
/// `true` on success.
pub const SyncFn = *const fn (from: NodeId, to: NodeId, reason: SyncReason) bool;

pub const SyncStats = struct {
    local_fast_path: usize = 0,
    cross_node_syncs: usize = 0,
    cross_node_failures: usize = 0,
};

pub const SyncPolicy = struct {
    sync_fn: SyncFn,
    stats: SyncStats = .{},

    const Self = @This();

    pub fn init(sync_fn: SyncFn) Self {
        return .{ .sync_fn = sync_fn };
    }

    /// Only performs synchronization when `local_node != target_node`.
    /// Same-node access never touches `sync_fn` at all - the fast
    /// path is unconditionally local.
    pub fn maybeSync(self: *Self, local_node: NodeId, target_node: NodeId, reason: SyncReason) bool {
        if (local_node == target_node) {
            self.stats.local_fast_path += 1;
            return true;
        }
        const ok = self.sync_fn(local_node, target_node, reason);
        if (ok) {
            self.stats.cross_node_syncs += 1;
        } else {
            self.stats.cross_node_failures += 1;
        }
        return ok;
    }
};

const testing = @import("std").testing;

fn alwaysSucceeds(from: NodeId, to: NodeId, reason: SyncReason) bool {
    _ = from;
    _ = to;
    _ = reason;
    return true;
}

fn alwaysFails(from: NodeId, to: NodeId, reason: SyncReason) bool {
    _ = from;
    _ = to;
    _ = reason;
    return false;
}

test "maybeSync takes the local fast path without invoking sync_fn" {
    var policy = SyncPolicy.init(alwaysFails);
    const ok = policy.maybeSync(2, 2, .cross_node_read);
    try testing.expect(ok);
    try testing.expectEqual(@as(usize, 1), policy.stats.local_fast_path);
    try testing.expectEqual(@as(usize, 0), policy.stats.cross_node_syncs);
}

test "maybeSync invokes sync_fn only for cross-node access" {
    var policy = SyncPolicy.init(alwaysSucceeds);
    const ok = policy.maybeSync(0, 3, .migration);
    try testing.expect(ok);
    try testing.expectEqual(@as(usize, 0), policy.stats.local_fast_path);
    try testing.expectEqual(@as(usize, 1), policy.stats.cross_node_syncs);
}

test "maybeSync records cross-node failures" {
    var policy = SyncPolicy.init(alwaysFails);
    const ok = policy.maybeSync(1, 5, .capability_revocation);
    try testing.expect(!ok);
    try testing.expectEqual(@as(usize, 1), policy.stats.cross_node_failures);
}
