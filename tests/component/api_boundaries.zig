const std = @import("std");
const wasm = @import("wavium-wasm");
const component = @import("wavium-component");
const wit = @import("wavium-wit");
const wasi = @import("wavium-wasi");
const security = @import("wavium-security");

test "component link requires resolved world match" {
    const worlds = [_]wit.WitWorld{.{ .name = "runtime", .import_count = 2, .export_count = 1 }};
    const pkg = try wit.parse("wavium:runtime", worlds[0..]);
    const world = try wit.resolveWorld(pkg, "runtime");

    var loader = component.ComponentLoader.init();
    const comp = try loader.loadComponent(.{ .name = "hello", .world = "runtime" });
    _ = try loader.link(comp, .{ .name = world.name });

    try std.testing.expectError(error.WorldMismatch, loader.link(comp, .{ .name = "storage" }));
}

test "wasi environment and capability checks are explicit" {
    var ctx = wasi.WasiContext.init(11);
    try std.testing.expectEqualStrings("runtime", ctx.environmentGet("wavium.mode").?);

    var perms = security.PermissionSet.empty;
    perms.insert(.storage_read);
    const token = security.issue(42, perms);

    try std.testing.expect(security.authorize(token, .storage_read));
    try std.testing.expect(!security.authorize(token, .storage_write));
}

test "wasm instance lifecycle boundary" {
    var engine = wasm.WasmEngine.init(.{});
    const bytes = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };

    const module = try engine.load(bytes[0..]);
    var inst = try engine.instantiate(module, .{});
    _ = try engine.execute(&inst, "run", "payload");

    engine.destroy(&inst);
    try std.testing.expectError(error.InstanceNotAlive, engine.execute(&inst, "run", "payload"));
}
