const std = @import("std");

pub const TargetLanguage = enum {
    zig,
    rust,
    go,
    c,
    python,
    javascript,
};

pub const SdkDescriptor = struct {
    language: TargetLanguage,
    package_name: []const u8,
    directory_name: []const u8,
};

pub const supported_sdks = [_]SdkDescriptor{
    .{ .language = .zig, .package_name = "wavium-zig-sdk", .directory_name = "sdks/wavium-zig-sdk" },
    .{ .language = .rust, .package_name = "wavium-rust-sdk", .directory_name = "sdks/wavium-rust-sdk" },
    .{ .language = .go, .package_name = "wavium-go-sdk", .directory_name = "sdks/wavium-go-sdk" },
    .{ .language = .c, .package_name = "wavium-c-sdk", .directory_name = "sdks/wavium-c-sdk" },
    .{ .language = .python, .package_name = "wavium-python-sdk", .directory_name = "sdks/wavium-python-sdk" },
    .{ .language = .javascript, .package_name = "wavium-js-sdk", .directory_name = "sdks/wavium-js-sdk" },
};

pub fn descriptor(language: TargetLanguage) ?SdkDescriptor {
    inline for (supported_sdks) |sdk| {
        if (sdk.language == language) return sdk;
    }
    return null;
}

pub fn packageName(language: TargetLanguage) ?[]const u8 {
    if (descriptor(language)) |sdk| return sdk.package_name;
    return null;
}

pub fn directoryName(language: TargetLanguage) ?[]const u8 {
    if (descriptor(language)) |sdk| return sdk.directory_name;
    return null;
}

pub fn sdkCount() usize {
    return supported_sdks.len;
}

pub fn allLanguages() [supported_sdks.len]TargetLanguage {
    return .{ .zig, .rust, .go, .c, .python, .javascript };
}

test "target language enum" {
    try std.testing.expectEqual(TargetLanguage.zig, TargetLanguage.zig);
}

test "sdk registry maps language to package and directory" {
    const zig_sdk = descriptor(.zig).?;
    try std.testing.expectEqualStrings("wavium-zig-sdk", zig_sdk.package_name);
    try std.testing.expectEqualStrings("sdks/wavium-zig-sdk", zig_sdk.directory_name);

    const js_sdk = descriptor(.javascript).?;
    try std.testing.expectEqualStrings("wavium-js-sdk", js_sdk.package_name);
    try std.testing.expectEqualStrings("sdks/wavium-js-sdk", js_sdk.directory_name);
}

test "sdk registry covers all package targets" {
    try std.testing.expectEqual(@as(usize, 6), sdkCount());
    try std.testing.expectEqual(@as(usize, 6), supported_sdks.len);
}
