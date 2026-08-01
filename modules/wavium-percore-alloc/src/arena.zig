//! Arena allocator: a bump/watermark allocator over a fixed backing
//! buffer owned entirely by one core. There is no lock, no atomic, and
//! no cross-core visibility at all - this is the fastest possible path
//! for short-lived, phase-scoped allocations (e.g. a single scheduling
//! quantum or a single message-handling pass) that are all released at
//! once via `reset()` rather than being freed individually.

pub const ArenaError = error{OutOfMemory};

pub const Arena = struct {
    buffer: []u8,
    offset: usize,

    pub fn init(buffer: []u8) Arena {
        return .{ .buffer = buffer, .offset = 0 };
    }

    /// Bumps the watermark forward and returns a slice of `size` bytes.
    /// No per-allocation bookkeeping is kept - allocations cannot be
    /// freed individually, only collectively via `reset()`.
    pub fn alloc(self: *Arena, size: usize) ArenaError![]u8 {
        if (self.offset + size > self.buffer.len) return ArenaError.OutOfMemory;
        const start = self.offset;
        self.offset += size;
        return self.buffer[start .. start + size];
    }

    /// Releases every allocation made so far in one O(1) step.
    pub fn reset(self: *Arena) void {
        self.offset = 0;
    }

    pub fn used(self: *const Arena) usize {
        return self.offset;
    }

    pub fn remaining(self: *const Arena) usize {
        return self.buffer.len - self.offset;
    }
};

const std = @import("std");
const testing = std.testing;

test "Arena bump-allocates sequential non-overlapping slices" {
    var backing: [64]u8 = undefined;
    var arena = Arena.init(&backing);

    const a = try arena.alloc(16);
    const b = try arena.alloc(16);
    try testing.expectEqual(@as(usize, 32), arena.used());
    try testing.expect(@intFromPtr(a.ptr) != @intFromPtr(b.ptr));
}

test "Arena reports OutOfMemory once capacity is exceeded" {
    var backing: [16]u8 = undefined;
    var arena = Arena.init(&backing);

    _ = try arena.alloc(16);
    try testing.expectError(ArenaError.OutOfMemory, arena.alloc(1));
}

test "Arena reset reclaims all space in one step" {
    var backing: [16]u8 = undefined;
    var arena = Arena.init(&backing);

    _ = try arena.alloc(16);
    try testing.expectEqual(@as(usize, 0), arena.remaining());
    arena.reset();
    try testing.expectEqual(@as(usize, 16), arena.remaining());
}
