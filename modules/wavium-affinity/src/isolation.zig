//! Core isolation: marks specific cores as reserved for
//! latency-sensitive, explicitly-pinned work only. Isolated cores are
//! excluded from general (non-pinned) scheduling placement decisions -
//! `latency.chooseLatencyOptimalCore` skips them - while a hard pin
//! (see `pin.zig`) may still target one deliberately, since that is an
//! explicit administrative decision that should always be honored.

const std = @import("std");
const testing = std.testing;
const entity_mod = @import("entity.zig");

pub const CoreId = entity_mod.CoreId;
pub const max_cores = 64;

pub const CoreIsolation = struct {
    mask: u64,

    pub fn init() CoreIsolation {
        return .{ .mask = 0 };
    }

    pub fn isolate(self: *CoreIsolation, cpu: CoreId) void {
        self.mask |= (@as(u64, 1) << @intCast(cpu));
    }

    pub fn release(self: *CoreIsolation, cpu: CoreId) void {
        self.mask &= ~(@as(u64, 1) << @intCast(cpu));
    }

    pub fn isIsolated(self: *const CoreIsolation, cpu: CoreId) bool {
        return (self.mask & (@as(u64, 1) << @intCast(cpu))) != 0;
    }
};

test "CoreIsolation isolates and releases individual cores" {
    var isolation = CoreIsolation.init();
    try testing.expect(!isolation.isIsolated(2));
    isolation.isolate(2);
    try testing.expect(isolation.isIsolated(2));
    isolation.release(2);
    try testing.expect(!isolation.isIsolated(2));
}

test "CoreIsolation tracks multiple isolated cores independently" {
    var isolation = CoreIsolation.init();
    isolation.isolate(0);
    isolation.isolate(5);
    try testing.expect(isolation.isIsolated(0));
    try testing.expect(isolation.isIsolated(5));
    try testing.expect(!isolation.isIsolated(1));
}
