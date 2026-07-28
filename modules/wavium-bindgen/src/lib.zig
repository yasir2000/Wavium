const std = @import("std");

pub const TargetLanguage = enum {
    zig,
    rust,
};

pub const GeneratorRequest = struct {
    namespace: []const u8,
    world: []const u8,
    interface_name: []const u8,
    function_name: []const u8,
    payload_type: ?[]const u8 = null,
};

const PayloadKind = enum {
    i32,
    bool,
    string,
};

pub fn moduleName() []const u8 {
    return "wavium-bindgen";
}

pub fn generateBindings(req: GeneratorRequest, lang: TargetLanguage, out: []u8) !usize {
    try validateRequest(req);

    return switch (lang) {
        .zig => generateZig(req, out),
        .rust => generateRust(req, out),
    };
}

fn validateRequest(req: GeneratorRequest) !void {
    if (req.namespace.len == 0) return error.InvalidNamespace;
    if (req.world.len == 0) return error.InvalidWorld;
    if (req.interface_name.len == 0) return error.InvalidInterface;
    if (req.function_name.len == 0) return error.InvalidFunction;

    try validateIdentifier(req.interface_name);
    try validateIdentifier(req.function_name);
    if (req.payload_type) |payload_type| {
        if (payloadAbiKind(payload_type) == null) return error.InvalidPayloadType;
    }
}

fn validateIdentifier(s: []const u8) !void {
    if (s.len == 0) return error.InvalidIdentifier;
    for (s, 0..) |ch, i| {
        const ok = std.ascii.isAlphabetic(ch) or std.ascii.isDigit(ch) or ch == '_';
        if (!ok) return error.InvalidIdentifier;
        if (i == 0 and std.ascii.isDigit(ch)) return error.InvalidIdentifier;
    }
}

fn payloadAbiKind(type_name: []const u8) ?PayloadKind {
    if (std.mem.eql(u8, type_name, "s32") or std.mem.eql(u8, type_name, "u32")) return .i32;
    if (std.mem.eql(u8, type_name, "bool")) return .bool;
    if (std.mem.eql(u8, type_name, "string")) return .string;
    return null;
}

fn payloadZigType(kind: PayloadKind) []const u8 {
    return switch (kind) {
        .i32 => "i32",
        .bool => "bool",
        .string => "[]const u8",
    };
}

fn payloadRustType(kind: PayloadKind) []const u8 {
    return switch (kind) {
        .i32 => "i32",
        .bool => "bool",
        .string => "&[u8]",
    };
}

fn generateZig(req: GeneratorRequest, out: []u8) !usize {
    var pos: usize = 0;
    const payload_kind = if (req.payload_type) |payload_type| payloadAbiKind(payload_type) else null;
    try append(out, &pos, "pub const ");
    try append(out, &pos, req.interface_name);
    try append(out, &pos, " = struct {\n");
    try append(out, &pos, "    pub fn ");
    try append(out, &pos, req.function_name);
    try append(out, &pos, "() void {}\n");
    if (payload_kind) |kind| {
        try append(out, &pos, "\n    pub const ");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "Payload = struct {\n        value: ");
        try append(out, &pos, payloadZigType(kind));
        try append(out, &pos, ",\n    };\n\n    pub fn abi_encode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(payload: ");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "Payload, out: []u8) !usize {\n");
        switch (kind) {
            .i32 => {
                try append(out, &pos, "        if (out.len < 4) return error.BufferTooSmall;\n");
                try append(out, &pos, "        std.mem.writeInt(i32, out[0..4], payload.value, .little);\n");
                try append(out, &pos, "        return 4;\n");
            },
            .bool => {
                try append(out, &pos, "        if (out.len < 1) return error.BufferTooSmall;\n");
                try append(out, &pos, "        out[0] = if (payload.value) 1 else 0;\n");
                try append(out, &pos, "        return 1;\n");
            },
            .string => {
                try append(out, &pos, "        if (payload.value.len > std.math.maxInt(u32)) return error.StringTooLong;\n");
                try append(out, &pos, "        const required: usize = 4 + payload.value.len;\n");
                try append(out, &pos, "        if (out.len < required) return error.BufferTooSmall;\n");
                try append(out, &pos, "        std.mem.writeInt(u32, out[0..4], @intCast(payload.value.len), .little);\n");
                try append(out, &pos, "        @memcpy(out[4..required], payload.value);\n");
                try append(out, &pos, "        return required;\n");
            },
        }
        try append(out, &pos, "    }\n\n    pub fn abi_decode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(data: []const u8) !");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "Payload {\n");
        switch (kind) {
            .i32 => {
                try append(out, &pos, "        if (data.len < 4) return error.BufferTooSmall;\n");
                try append(out, &pos, "        return .{ .value = std.mem.readInt(i32, data[0..4], .little) };\n");
            },
            .bool => {
                try append(out, &pos, "        if (data.len < 1) return error.BufferTooSmall;\n");
                try append(out, &pos, "        return switch (data[0]) {\n");
                try append(out, &pos, "            0 => .{ .value = false },\n");
                try append(out, &pos, "            1 => .{ .value = true },\n");
                try append(out, &pos, "            else => error.InvalidBooleanEncoding,\n");
                try append(out, &pos, "        };\n");
            },
            .string => {
                try append(out, &pos, "        if (data.len < 4) return error.BufferTooSmall;\n");
                try append(out, &pos, "        const len = std.mem.readInt(u32, data[0..4], .little);\n");
                try append(out, &pos, "        const required: usize = 4 + len;\n");
                try append(out, &pos, "        if (data.len < required) return error.BufferTooSmall;\n");
                try append(out, &pos, "        return .{ .value = data[4..required] };\n");
            },
        }
        try append(out, &pos, "    }\n");
    } else {
        try append(out, &pos, "\n    pub fn abi_encode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(_out: []u8) usize {\n");
        try append(out, &pos, "        _ = _out;\n");
        try append(out, &pos, "        return 0;\n");
        try append(out, &pos, "    }\n\n    pub fn abi_decode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(_in: []const u8) void {\n");
        try append(out, &pos, "        _ = _in;\n");
        try append(out, &pos, "    }\n");
    }
    try append(out, &pos, "};\n");
    return pos;
}

fn generateRust(req: GeneratorRequest, out: []u8) !usize {
    var pos: usize = 0;
    const payload_kind = if (req.payload_type) |payload_type| payloadAbiKind(payload_type) else null;
    try append(out, &pos, "pub mod ");
    try append(out, &pos, req.interface_name);
    try append(out, &pos, " {\n");
    try append(out, &pos, "    pub fn ");
    try append(out, &pos, req.function_name);
    try append(out, &pos, "() {}\n");
    if (payload_kind) |kind| {
        try append(out, &pos, "\n    pub struct ");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "Payload {\n        pub value: ");
        try append(out, &pos, payloadRustType(kind));
        try append(out, &pos, ",\n    }\n\n    pub fn abi_encode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(payload: &");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "Payload, out: &mut [u8]) -> usize {\n");
        switch (kind) {
            .i32 => {
                try append(out, &pos, "        if out.len < 4 { return 0; }\n");
                try append(out, &pos, "        out[0..4].copy_from_slice(&payload.value.to_le_bytes());\n");
                try append(out, &pos, "        4\n");
            },
            .bool => {
                try append(out, &pos, "        if out.len < 1 { return 0; }\n");
                try append(out, &pos, "        out[0] = if payload.value { 1 } else { 0 };\n");
                try append(out, &pos, "        1\n");
            },
            .string => {
                try append(out, &pos, "        if payload.value.len() > u32::MAX as usize { return 0; }\n");
                try append(out, &pos, "        let required = 4 + payload.value.len();\n");
                try append(out, &pos, "        if out.len() < required { return 0; }\n");
                try append(out, &pos, "        out[0..4].copy_from_slice(&(payload.value.len() as u32).to_le_bytes());\n");
                try append(out, &pos, "        out[4..required].copy_from_slice(payload.value);\n");
                try append(out, &pos, "        required\n");
            },
        }
        try append(out, &pos, "    }\n\n    pub fn abi_decode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(data: &[u8]) -> ");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "Payload {\n");
        switch (kind) {
            .i32 => {
                try append(out, &pos, "        let mut bytes = [0u8; 4];\n");
                try append(out, &pos, "        bytes.copy_from_slice(&data[0..4]);\n");
                try append(out, &pos, "        ");
                try append(out, &pos, req.function_name);
                try append(out, &pos, "Payload { value: i32::from_le_bytes(bytes) }\n");
            },
            .bool => {
                try append(out, &pos, "        ");
                try append(out, &pos, req.function_name);
                try append(out, &pos, "Payload { value: data[0] != 0 }\n");
            },
            .string => {
                try append(out, &pos, "        let mut len_bytes = [0u8; 4];\n");
                try append(out, &pos, "        len_bytes.copy_from_slice(&data[0..4]);\n");
                try append(out, &pos, "        let len = u32::from_le_bytes(len_bytes) as usize;\n");
                try append(out, &pos, "        ");
                try append(out, &pos, req.function_name);
                try append(out, &pos, "Payload { value: &data[4..4 + len] }\n");
            },
        }
        try append(out, &pos, "    }\n");
    } else {
        try append(out, &pos, "\n    pub fn abi_encode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(_out: &mut [u8]) -> usize {\n");
        try append(out, &pos, "        let _ = _out;\n");
        try append(out, &pos, "        0\n");
        try append(out, &pos, "    }\n\n    pub fn abi_decode_");
        try append(out, &pos, req.function_name);
        try append(out, &pos, "(_in: &[u8]) {\n");
        try append(out, &pos, "        let _ = _in;\n");
        try append(out, &pos, "    }\n");
    }
    try append(out, &pos, "}\n");
    return pos;
}

fn append(out: []u8, pos: *usize, data: []const u8) !void {
    const end = pos.* + data.len;
    if (end > out.len) return error.BufferTooSmall;
    @memcpy(out[pos.*..end], data);
    pos.* = end;
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-bindgen", moduleName());
}

test "generate zig binding stub" {
    var buf: [256]u8 = undefined;
    const used = try generateBindings(.{
        .namespace = "wavium",
        .world = "runtime",
        .interface_name = "storage",
        .function_name = "put",
    }, .zig, buf[0..]);

    try std.testing.expect(used > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub const storage") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub fn put") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "abi_encode_put") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "abi_decode_put") != null);
}

test "generate zig typed payload binding" {
    var buf: [1024]u8 = undefined;
    const used = try generateBindings(.{
        .namespace = "wavium",
        .world = "runtime",
        .interface_name = "storage",
        .function_name = "put",
        .payload_type = "string",
    }, .zig, buf[0..]);

    try std.testing.expect(used > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub const putPayload = struct") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "value: []const u8") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub fn abi_encode_put(payload: putPayload") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub fn abi_decode_put(data: []const u8) !putPayload") != null);
}

test "generate rust binding stub" {
    var buf: [256]u8 = undefined;
    const used = try generateBindings(.{
        .namespace = "wavium",
        .world = "runtime",
        .interface_name = "storage",
        .function_name = "put",
    }, .rust, buf[0..]);

    try std.testing.expect(used > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub mod storage") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub fn put") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "abi_encode_put") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "abi_decode_put") != null);
}

test "generate rust typed payload binding" {
    var buf: [1024]u8 = undefined;
    const used = try generateBindings(.{
        .namespace = "wavium",
        .world = "runtime",
        .interface_name = "storage",
        .function_name = "put",
        .payload_type = "u32",
    }, .rust, buf[0..]);

    try std.testing.expect(used > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub struct putPayload") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub value: i32") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub fn abi_encode_put(payload: &putPayload") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "pub fn abi_decode_put(data: &[u8]) -> putPayload") != null);
}

test "invalid identifier rejected" {
    var buf: [128]u8 = undefined;
    try std.testing.expectError(error.InvalidIdentifier, generateBindings(.{
        .namespace = "wavium",
        .world = "runtime",
        .interface_name = "bad-name",
        .function_name = "put",
    }, .zig, buf[0..]));
}

test "invalid payload type rejected" {
    var buf: [128]u8 = undefined;
    try std.testing.expectError(error.InvalidPayloadType, generateBindings(.{
        .namespace = "wavium",
        .world = "runtime",
        .interface_name = "storage",
        .function_name = "put",
        .payload_type = "record{a:u32}",
    }, .zig, buf[0..]));
}
