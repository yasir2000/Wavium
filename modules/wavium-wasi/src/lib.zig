const std = @import("std");

pub const ResourcePermission = enum {
    storage_read,
    storage_write,
};

pub const AuthorizationFn = *const fn (ctx: *const anyopaque, permission: ResourcePermission) bool;

pub const WasiContext = struct {
    monotonic_ns: u64,
    random_state: u64,

    pub fn init(seed: u64) WasiContext {
        return .{
            .monotonic_ns = 0,
            .random_state = if (seed == 0) 0x9e3779b97f4a7c15 else seed,
        };
    }

    pub fn clockMonotonicNs(self: *WasiContext) u64 {
        self.monotonic_ns += 1;
        return self.monotonic_ns;
    }

    pub fn randomU64(self: *WasiContext) u64 {
        var x = self.random_state;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.random_state = x;
        return x *% 2685821657736338717;
    }

    pub fn environmentGet(_: *WasiContext, key: []const u8) ?[]const u8 {
        if (std.mem.eql(u8, key, "wavium.mode")) return "runtime";
        return null;
    }

    pub fn storageRead(_: *WasiContext, key: []const u8, auth_ctx: *const anyopaque, authorize: AuthorizationFn) ![]const u8 {
        if (!authorize(auth_ctx, .storage_read)) return error.PermissionDenied;

        if (std.mem.eql(u8, key, "demo")) return "value";
        return error.NotFound;
    }

    pub fn storageWrite(_: *WasiContext, key: []const u8, value: []const u8, auth_ctx: *const anyopaque, authorize: AuthorizationFn) !void {
        if (!authorize(auth_ctx, .storage_write)) return error.PermissionDenied;
        if (key.len == 0 or value.len == 0) return error.InvalidWrite;
    }
};

fn allowReadOnly(_: *const anyopaque, permission: ResourcePermission) bool {
    return permission == .storage_read;
}

fn denyAll(_: *const anyopaque, _: ResourcePermission) bool {
    return false;
}

test "wasi clock shape" {
    var ctx = WasiContext.init(7);
    try std.testing.expectEqual(@as(u64, 1), ctx.clockMonotonicNs());
    try std.testing.expect(ctx.randomU64() != 0);
    try std.testing.expectEqualStrings("runtime", ctx.environmentGet("wavium.mode").?);

    const auth_ctx: *const anyopaque = @ptrFromInt(1);
    try std.testing.expectEqualStrings("value", try ctx.storageRead("demo", auth_ctx, allowReadOnly));
    try std.testing.expectError(error.PermissionDenied, ctx.storageWrite("demo", "x", auth_ctx, allowReadOnly));
    try std.testing.expectError(error.PermissionDenied, ctx.storageRead("demo", auth_ctx, denyAll));
}
