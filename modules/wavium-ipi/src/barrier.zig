const std = @import("std");

/// Cross-core synchronization barrier: `expected` participants must each
/// call `arrive()` before any of them may proceed past the barrier. Backed
/// by a single atomic counter with acquire/release ordering, giving every
/// core that observes the barrier as "released" a happens-before view of
/// every write made by every other participant before it called
/// `arrive()` - i.e. cross-core memory synchronization, not just a count.
pub const Barrier = struct {
    expected: usize,
    arrived: std.atomic.Value(usize),

    pub fn init(expected: usize) Barrier {
        return .{ .expected = expected, .arrived = std.atomic.Value(usize).init(0) };
    }

    /// Registers this core's arrival. Returns true exactly once - for
    /// whichever caller happens to be the last (`expected`th) arrival.
    pub fn arrive(self: *Barrier) bool {
        const previous = self.arrived.fetchAdd(1, .acq_rel);
        return previous + 1 == self.expected;
    }

    pub fn arrivedCount(self: *Barrier) usize {
        return self.arrived.load(.acquire);
    }

    pub fn isReleased(self: *Barrier) bool {
        return self.arrivedCount() >= self.expected;
    }

    pub fn reset(self: *Barrier) void {
        self.arrived.store(0, .release);
    }
};

test "barrier releases only once every participant has arrived" {
    var b = Barrier.init(3);
    try std.testing.expect(!b.isReleased());
    try std.testing.expect(!b.arrive());
    try std.testing.expect(!b.arrive());
    try std.testing.expect(b.arrive());
    try std.testing.expect(b.isReleased());
}

test "barrier reports true only for the arrival that completes it" {
    var b = Barrier.init(1);
    try std.testing.expect(b.arrive());
}

test "reset allows a barrier to be reused for a subsequent round" {
    var b = Barrier.init(2);
    _ = b.arrive();
    _ = b.arrive();
    try std.testing.expect(b.isReleased());

    b.reset();
    try std.testing.expect(!b.isReleased());
    try std.testing.expectEqual(@as(usize, 0), b.arrivedCount());
}
