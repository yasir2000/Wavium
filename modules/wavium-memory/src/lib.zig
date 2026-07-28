const std = @import("std");

pub const Arena = @import("arena.zig").Arena;
pub const Quota = @import("quota.zig").Quota;

test "arena deterministic allocation" {
    var buf: [128]u8 = undefined;
    var arena = Arena.init(buf[0..]);

    const a = try arena.alloc(16, 8);
    const b = try arena.alloc(16, 8);

    try std.testing.expect(a.len == 16);
    try std.testing.expect(b.len == 16);
    try std.testing.expect(@intFromPtr(b.ptr) > @intFromPtr(a.ptr));
}

test "quota enforcement" {
    var quota = Quota.init(32);
    try quota.reserve(16);
    try quota.reserve(16);
    try std.testing.expectError(error.QuotaExceeded, quota.reserve(1));
}
