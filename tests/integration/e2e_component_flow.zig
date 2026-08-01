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

var e2e_wasm_engine: wasm.WasmEngine = undefined;
var e2e_wasm_module: wasm.WasmModule = undefined;
var e2e_wasm_instance: wasm.Instance = undefined;

/// Adapts `wavium-wasm`'s concrete engine to `wavium-component`'s
/// backend-agnostic `ExecutionBackend` interface, proving the component
/// runtime (Prompt 11) can drive a real WASM engine through opaque
/// instantiate/invoke/destroy function pointers rather than the two
/// modules calling into each other's concrete types directly.
fn wasmInstantiate(_: component.LinkedComponent) component.RuntimeError!*anyopaque {
    e2e_wasm_instance = e2e_wasm_engine.instantiate(e2e_wasm_module, .{}) catch return error.BackendInstantiateFailed;
    return @ptrCast(&e2e_wasm_instance);
}

fn wasmInvoke(handle: *anyopaque, entry: []const u8, args: []const u8) component.RuntimeError!usize {
    const inst: *wasm.Instance = @ptrCast(@alignCast(handle));
    const result = e2e_wasm_engine.execute(inst, entry, args) catch return error.NotInstantiated;
    return result.bytes_returned;
}

fn wasmDestroy(handle: *anyopaque) void {
    const inst: *wasm.Instance = @ptrCast(@alignCast(handle));
    e2e_wasm_engine.destroy(inst);
}

test "e2e wit->component->wasm execute" {
    const worlds = [_]wit.WitWorld{.{ .name = "runtime", .import_count = 1, .export_count = 1 }};
    const pkg = try wit.parse("wavium:runtime", worlds[0..]);
    const world = try wit.resolveWorld(pkg, "runtime");

    var loader = component.ComponentLoader.init();
    const comp = try loader.loadComponent(.{ .name = "hello-component", .world = "runtime" });
    const linked = try loader.link(comp, .{ .name = world.name });

    e2e_wasm_engine = wasm.WasmEngine.init(.{});
    const bytes = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
    e2e_wasm_module = try e2e_wasm_engine.load(bytes[0..]);

    const backend = component.ExecutionBackend{ .instantiate = wasmInstantiate, .invoke = wasmInvoke, .destroy = wasmDestroy };
    const runtime = component.ComponentRuntime.init(backend);
    var running = try runtime.start(linked);
    const bytes_returned = try running.invoke("run", "hello");
    try std.testing.expectEqual(@as(usize, 5), bytes_returned);

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

    running.shutdown();
    try std.testing.expectError(component.RuntimeError.NotInstantiated, running.invoke("run", "hello"));
}
