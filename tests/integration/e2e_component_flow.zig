const std = @import("std");
const wasm = @import("wavium-wasm");
const component = @import("wavium-component");
const wit = @import("wavium-wit");
const wasi = @import("wavium-wasi");
const security = @import("wavium-security");

fn authorizeFromToken(ctx: *const anyopaque, permission: wasi.ResourcePermission) bool {
    const token: *const security.CapabilityToken = @ptrCast(@alignCast(ctx));
    return switch (permission) {
        .storage_read => security.authorize(token.*, .storage_read),
        .storage_write => security.authorize(token.*, .storage_write),
    };
}

test "e2e wit->component->wasm execute" {
    const worlds = [_]wit.WitWorld{.{ .name = "runtime", .import_count = 1, .export_count = 1 }};
    const pkg = try wit.parse("wavium:runtime", worlds[0..]);
    const world = try wit.resolveWorld(pkg, "runtime");

    var loader = component.ComponentLoader.init();
    const comp = try loader.loadComponent(.{ .name = "hello-component", .world = "runtime" });
    _ = try loader.link(comp, .{ .name = world.name });

    var engine = wasm.WasmEngine.init(.{});
    const bytes = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
    const module = try engine.load(bytes[0..]);
    var inst = try engine.instantiate(module, .{});
    const exec = try engine.execute(&inst, "run", "hello");
    try std.testing.expectEqual(@as(usize, 5), exec.bytes_returned);

    var wasi_ctx = wasi.WasiContext.init(7);
    try std.testing.expectEqualStrings("runtime", wasi_ctx.environmentGet("wavium.mode").?);

    var read_only_perms = security.PermissionSet.empty;
    read_only_perms.insert(.storage_read);
    const read_only_token = security.issue(99, read_only_perms);

    const token_ctx: *const anyopaque = @ptrCast(&read_only_token);
    try std.testing.expectEqualStrings("value", try wasi_ctx.storageRead("demo", token_ctx, authorizeFromToken));
    try std.testing.expectError(error.PermissionDenied, wasi_ctx.storageWrite("demo", "new-value", token_ctx, authorizeFromToken));

    var read_write_perms = security.PermissionSet.empty;
    read_write_perms.insert(.storage_read);
    read_write_perms.insert(.storage_write);
    const read_write_token = security.issue(100, read_write_perms);
    const rw_token_ctx: *const anyopaque = @ptrCast(&read_write_token);
    try wasi_ctx.storageWrite("demo", "new-value", rw_token_ctx, authorizeFromToken);

    engine.destroy(&inst);
    try std.testing.expectError(error.InstanceNotAlive, engine.execute(&inst, "run", "hello"));
}
