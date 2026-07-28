const std = @import("std");

pub const ComponentDescriptor = struct {
    name: []const u8,
    wit_world: []const u8,
    template: []const u8,
};

pub const WasmInspection = struct {
    valid_magic: bool,
    version: u32,
};

pub const ComposedComponent = struct {
    name: []const u8,
    wit_world: []const u8,
    adapter_count: u16,
};

pub const SignIntent = struct {
    component_name: []const u8,
    key_id: []const u8,
};

pub fn moduleName() []const u8 {
    return "wavium-component-tools";
}

pub fn componentCreate(name: []const u8, wit_world: []const u8) !ComponentDescriptor {
    if (name.len == 0) return error.InvalidComponentName;
    try validateWitWorld(wit_world);

    return .{
        .name = name,
        .wit_world = wit_world,
        .template = "component-template-v1",
    };
}

pub fn validateWitWorld(wit_world: []const u8) !void {
    if (wit_world.len == 0) return error.InvalidWitWorld;
    for (wit_world) |ch| {
        const ok = std.ascii.isAlphabetic(ch) or std.ascii.isDigit(ch) or ch == '_' or ch == '-';
        if (!ok) return error.InvalidWitWorld;
    }
}

pub fn componentInspect(wasm_bytes: []const u8) !WasmInspection {
    if (wasm_bytes.len < 8) return error.InvalidWasmBinary;

    const valid_magic = wasm_bytes[0] == 0x00 and wasm_bytes[1] == 0x61 and wasm_bytes[2] == 0x73 and wasm_bytes[3] == 0x6d;
    const version_ptr: *const [4]u8 = @ptrCast(wasm_bytes[4..8].ptr);
    const version = std.mem.readInt(u32, version_ptr, .little);

    return .{
        .valid_magic = valid_magic,
        .version = version,
    };
}

pub fn componentCompose(base: ComponentDescriptor, adapter_count: u16) !ComposedComponent {
    if (adapter_count == 0) return error.InvalidAdapterCount;
    return .{
        .name = base.name,
        .wit_world = base.wit_world,
        .adapter_count = adapter_count,
    };
}

pub fn componentSignIntent(component_name: []const u8, key_id: []const u8) !SignIntent {
    if (component_name.len == 0) return error.InvalidComponentName;
    if (key_id.len == 0) return error.InvalidKeyId;
    return .{ .component_name = component_name, .key_id = key_id };
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-component-tools", moduleName());
}

test "component create and validate" {
    const c = try componentCreate("payment", "runtime");
    try std.testing.expectEqualStrings("payment", c.name);
    try std.testing.expectError(error.InvalidWitWorld, componentCreate("x", "runtime:bad"));
}

test "component inspect wasm header" {
    const bytes = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
    const info = try componentInspect(bytes[0..]);
    try std.testing.expect(info.valid_magic);
    try std.testing.expectEqual(@as(u32, 1), info.version);
}

test "compose and sign intent" {
    const c = try componentCreate("hello", "runtime");
    const composed = try componentCompose(c, 2);
    try std.testing.expectEqual(@as(u16, 2), composed.adapter_count);

    const intent = try componentSignIntent("hello", "root-key");
    try std.testing.expectEqualStrings("root-key", intent.key_id);
}
