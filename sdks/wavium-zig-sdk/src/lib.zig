const std = @import("std");

pub const version = "0.1.0";

pub fn sdkName() []const u8 {
    return "wavium-zig-sdk";
}

pub fn packageName() []const u8 {
    return "wavium";
}

/// An opaque, runtime-issued capability handle. Resource access always
/// flows through a handle like this rather than an ambient API.
pub const CapabilityHandle = struct {
    id: u64,

    pub fn isValid(self: CapabilityHandle) bool {
        return self.id != 0;
    }
};

pub const AbiError = error{
    BufferTooSmall,
    InvalidBooleanEncoding,
    StringTooLong,
};

/// Canonical ABI codecs. These mirror the encoding used by wavium-wit so
/// that payloads produced by this SDK are wire-compatible with the runtime.
pub fn encodeI32(value: i32, out: []u8) AbiError!usize {
    if (out.len < 4) return error.BufferTooSmall;
    std.mem.writeInt(i32, out[0..4], value, .little);
    return 4;
}

pub fn decodeI32(data: []const u8) AbiError!i32 {
    if (data.len < 4) return error.BufferTooSmall;
    return std.mem.readInt(i32, data[0..4], .little);
}

pub fn encodeBool(value: bool, out: []u8) AbiError!usize {
    if (out.len < 1) return error.BufferTooSmall;
    out[0] = if (value) 1 else 0;
    return 1;
}

pub fn decodeBool(data: []const u8) AbiError!bool {
    if (data.len < 1) return error.BufferTooSmall;
    return switch (data[0]) {
        0 => false,
        1 => true,
        else => error.InvalidBooleanEncoding,
    };
}

pub fn encodeString(value: []const u8, out: []u8) AbiError!usize {
    if (value.len > std.math.maxInt(u32)) return error.StringTooLong;
    const required: usize = 4 + value.len;
    if (out.len < required) return error.BufferTooSmall;
    std.mem.writeInt(u32, out[0..4], @intCast(value.len), .little);
    @memcpy(out[4..required], value);
    return required;
}

pub fn decodeString(data: []const u8) AbiError![]const u8 {
    if (data.len < 4) return error.BufferTooSmall;
    const len = std.mem.readInt(u32, data[0..4], .little);
    const required: usize = 4 + len;
    if (data.len < required) return error.BufferTooSmall;
    return data[4..required];
}

test "sdk name" {
    try std.testing.expectEqualStrings("wavium-zig-sdk", sdkName());
}

test "capability handle validity" {
    try std.testing.expect(!(CapabilityHandle{ .id = 0 }).isValid());
    try std.testing.expect((CapabilityHandle{ .id = 7 }).isValid());
}

test "abi encode decode i32" {
    var buf: [4]u8 = undefined;
    _ = try encodeI32(-99, buf[0..]);
    try std.testing.expectEqual(@as(i32, -99), try decodeI32(buf[0..]));
}

test "abi encode decode bool" {
    var buf: [1]u8 = undefined;
    _ = try encodeBool(true, buf[0..]);
    try std.testing.expect(try decodeBool(buf[0..]));
    try std.testing.expectError(error.InvalidBooleanEncoding, decodeBool(&[_]u8{9}));
}

test "abi encode decode string" {
    var buf: [32]u8 = undefined;
    const used = try encodeString("wavium-sdk", buf[0..]);
    try std.testing.expectEqualStrings("wavium-sdk", try decodeString(buf[0..used]));
}
