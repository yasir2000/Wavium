const std = @import("std");

pub const WitWorld = struct {
    name: []const u8,
    import_count: u16,
    export_count: u16,
    imports: []const WitInterface = &.{},
    exports: []const WitInterface = &.{},
};

pub const WitPackage = struct {
    namespace: []const u8,
    world: []const u8,
    worlds: []const WitWorld,
};

/// A single named function signature within a WIT interface, expressed in
/// terms of canonical ABI types (Prompt 12: WIT interface definitions).
pub const WitFunctionSignature = struct {
    name: []const u8,
    params: []const CanonicalAbiType,
    results: []const CanonicalAbiType,
};

pub const WitInterface = struct {
    name: []const u8,
    functions: []const WitFunctionSignature,
};

pub const WitInterfaceError = error{
    ImportCountMismatch,
    ExportCountMismatch,
    FunctionNotFound,
    ArgumentCountMismatch,
    ArgumentTypeMismatch,
};

pub const CanonicalAbiType = enum {
    i32,
    i64,
    f32,
    f64,
    bool,
    string,
    list,
    record,
    flags,
    unknown,
};

pub fn canonicalAbiType(type_name: []const u8) CanonicalAbiType {
    if (std.mem.eql(u8, type_name, "s32") or std.mem.eql(u8, type_name, "u32")) return .i32;
    if (std.mem.eql(u8, type_name, "s64") or std.mem.eql(u8, type_name, "u64")) return .i64;
    if (std.mem.eql(u8, type_name, "f32")) return .f32;
    if (std.mem.eql(u8, type_name, "f64")) return .f64;
    if (std.mem.eql(u8, type_name, "bool")) return .bool;
    if (std.mem.eql(u8, type_name, "string")) return .string;
    if (std.mem.startsWith(u8, type_name, "list<")) return .list;
    if (std.mem.startsWith(u8, type_name, "record{")) return .record;
    if (std.mem.startsWith(u8, type_name, "flags{")) return .flags;
    return .unknown;
}

pub fn encodeI32Le(value: i32, out: []u8) !usize {
    if (out.len < 4) return error.BufferTooSmall;
    std.mem.writeInt(i32, out[0..4], value, .little);
    return 4;
}

pub fn decodeI32Le(data: []const u8) !i32 {
    if (data.len < 4) return error.BufferTooSmall;
    return std.mem.readInt(i32, data[0..4], .little);
}

pub fn encodeBool(value: bool, out: []u8) !usize {
    if (out.len < 1) return error.BufferTooSmall;
    out[0] = if (value) 1 else 0;
    return 1;
}

pub fn decodeBool(data: []const u8) !bool {
    if (data.len < 1) return error.BufferTooSmall;
    return switch (data[0]) {
        0 => false,
        1 => true,
        else => error.InvalidBooleanEncoding,
    };
}

pub fn encodeStringLenPrefixed(value: []const u8, out: []u8) !usize {
    if (value.len > std.math.maxInt(u32)) return error.StringTooLong;
    const required: usize = 4 + value.len;
    if (out.len < required) return error.BufferTooSmall;

    std.mem.writeInt(u32, out[0..4], @intCast(value.len), .little);
    @memcpy(out[4..required], value);
    return required;
}

pub fn decodeStringLenPrefixed(data: []const u8) ![]const u8 {
    if (data.len < 4) return error.BufferTooSmall;
    const len = std.mem.readInt(u32, data[0..4], .little);
    const required: usize = 4 + len;
    if (data.len < required) return error.BufferTooSmall;
    return data[4..required];
}

pub fn parse(source: []const u8, worlds: []const WitWorld) !WitPackage {
    var parts = std.mem.splitScalar(u8, source, ':');
    const namespace = parts.next() orelse return error.InvalidWitPackage;
    const world = parts.next() orelse return error.InvalidWitPackage;
    if (parts.next() != null) return error.InvalidWitPackage;

    if (namespace.len == 0 or world.len == 0) return error.InvalidWitPackage;
    return .{ .namespace = namespace, .world = world, .worlds = worlds };
}

pub fn resolveWorld(pkg: WitPackage, name: []const u8) !WitWorld {
    for (pkg.worlds) |w| {
        if (std.mem.eql(u8, w.name, name)) return w;
    }
    return error.WorldNotFound;
}

/// Validates that a world's declared `imports`/`exports` interface lists
/// (when populated) agree with its numeric `import_count`/`export_count`
/// fields, catching a world definition where the interface list drifted
/// out of sync with the summary counts.
pub fn validateWorldInterfaceCounts(world: WitWorld) WitInterfaceError!void {
    if (world.imports.len != 0 and world.imports.len != world.import_count) {
        return error.ImportCountMismatch;
    }
    if (world.exports.len != 0 and world.exports.len != world.export_count) {
        return error.ExportCountMismatch;
    }
}

pub fn findFunction(interface: WitInterface, name: []const u8) ?WitFunctionSignature {
    for (interface.functions) |f| {
        if (std.mem.eql(u8, f.name, name)) return f;
    }
    return null;
}

/// Validates a prospective call's argument types against a WIT function
/// signature's declared parameter types before the call crosses the
/// canonical ABI boundary into the WASM instance.
pub fn validateCallSignature(sig: WitFunctionSignature, arg_types: []const CanonicalAbiType) WitInterfaceError!void {
    if (sig.params.len != arg_types.len) {
        return error.ArgumentCountMismatch;
    }
    for (sig.params, arg_types) |expected, actual| {
        if (expected != actual) {
            return error.ArgumentTypeMismatch;
        }
    }
}

test "wit package fields" {
    const worlds = [_]WitWorld{.{ .name = "runtime", .import_count = 1, .export_count = 1 }};
    const pkg = try parse("wavium:runtime", worlds[0..]);
    try std.testing.expectEqualStrings("wavium", pkg.namespace);

    const world = try resolveWorld(pkg, "runtime");
    try std.testing.expectEqual(@as(u16, 1), world.import_count);
    try std.testing.expectError(error.WorldNotFound, resolveWorld(pkg, "missing"));
}

test "canonical abi type mapping" {
    try std.testing.expectEqual(CanonicalAbiType.i32, canonicalAbiType("u32"));
    try std.testing.expectEqual(CanonicalAbiType.string, canonicalAbiType("string"));
    try std.testing.expectEqual(CanonicalAbiType.list, canonicalAbiType("list<u8>"));
    try std.testing.expectEqual(CanonicalAbiType.record, canonicalAbiType("record{a:u32}"));
    try std.testing.expectEqual(CanonicalAbiType.unknown, canonicalAbiType("future_type"));
}

test "canonical abi encode decode i32" {
    var buf: [4]u8 = undefined;
    _ = try encodeI32Le(-42, buf[0..]);
    const value = try decodeI32Le(buf[0..]);
    try std.testing.expectEqual(@as(i32, -42), value);
}

test "canonical abi bool encoding" {
    var buf: [1]u8 = undefined;
    _ = try encodeBool(true, buf[0..]);
    try std.testing.expect(try decodeBool(buf[0..]));
    try std.testing.expectError(error.InvalidBooleanEncoding, decodeBool(&[_]u8{2}));
}

test "canonical abi string len-prefixed" {
    var buf: [32]u8 = undefined;
    const used = try encodeStringLenPrefixed("wavium", buf[0..]);
    try std.testing.expectEqual(@as(usize, 10), used);

    const decoded = try decodeStringLenPrefixed(buf[0..used]);
    try std.testing.expectEqualStrings("wavium", decoded);
}

test "validateWorldInterfaceCounts accepts empty interface lists and matching counts" {
    const bare_world = WitWorld{ .name = "runtime", .import_count = 1, .export_count = 1 };
    try validateWorldInterfaceCounts(bare_world);

    const export_fns = [_]WitFunctionSignature{.{ .name = "run", .params = &.{.string}, .results = &.{.i32} }};
    const exports = [_]WitInterface{.{ .name = "runtime-api", .functions = export_fns[0..] }};
    const detailed_world = WitWorld{ .name = "runtime", .import_count = 0, .export_count = 1, .exports = exports[0..] };
    try validateWorldInterfaceCounts(detailed_world);
}

test "validateWorldInterfaceCounts rejects drifted counts" {
    const exports = [_]WitInterface{ .{ .name = "a", .functions = &.{} }, .{ .name = "b", .functions = &.{} } };
    const world = WitWorld{ .name = "runtime", .import_count = 0, .export_count = 1, .exports = exports[0..] };
    try std.testing.expectError(WitInterfaceError.ExportCountMismatch, validateWorldInterfaceCounts(world));
}

test "findFunction and validateCallSignature enforce parameter types" {
    const functions = [_]WitFunctionSignature{.{ .name = "run", .params = &.{ .string, .i32 }, .results = &.{.bool} }};
    const iface = WitInterface{ .name = "runtime-api", .functions = functions[0..] };

    const sig = findFunction(iface, "run").?;
    try validateCallSignature(sig, &.{ .string, .i32 });
    try std.testing.expectError(WitInterfaceError.ArgumentCountMismatch, validateCallSignature(sig, &.{.string}));
    try std.testing.expectError(WitInterfaceError.ArgumentTypeMismatch, validateCallSignature(sig, &.{ .i32, .string }));

    try std.testing.expect(findFunction(iface, "missing") == null);
}
