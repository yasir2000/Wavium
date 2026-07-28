const std = @import("std");

pub const Signature = struct {
    key_id: []const u8,
    value: u64,
};

pub const TrustRegistry = struct {
    allocator: std.mem.Allocator,
    trusted_keys: std.StringHashMap(void),

    pub fn init(allocator: std.mem.Allocator) TrustRegistry {
        return .{
            .allocator = allocator,
            .trusted_keys = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *TrustRegistry) void {
        self.trusted_keys.deinit();
    }

    pub fn addTrustedKey(self: *TrustRegistry, key_id: []const u8) !void {
        if (key_id.len == 0) return error.InvalidKeyId;
        try self.trusted_keys.put(key_id, {});
    }

    pub fn isTrusted(self: *TrustRegistry, key_id: []const u8) bool {
        return self.trusted_keys.contains(key_id);
    }
};

pub fn moduleName() []const u8 {
    return "wavium-security-tools";
}

pub fn signDigest(key_material: []const u8, key_id: []const u8, digest: u64) !Signature {
    if (key_material.len == 0) return error.InvalidKeyMaterial;
    if (key_id.len == 0) return error.InvalidKeyId;

    const key_hash = std.hash.Wyhash.hash(0, key_material);
    return .{
        .key_id = key_id,
        .value = digest ^ key_hash,
    };
}

pub fn verifyDigestSignature(key_material: []const u8, digest: u64, signature: Signature) !void {
    if (key_material.len == 0) return error.InvalidKeyMaterial;
    if (signature.key_id.len == 0) return error.InvalidKeyId;

    const key_hash = std.hash.Wyhash.hash(0, key_material);
    const expected = digest ^ key_hash;
    if (expected != signature.value) return error.SignatureMismatch;
}

pub fn verifyTrusted(registry: *TrustRegistry, signature: Signature) !void {
    if (!registry.isTrusted(signature.key_id)) return error.UntrustedKey;
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-security-tools", moduleName());
}

test "sign and verify digest" {
    const digest: u64 = 0x1234;
    const sig = try signDigest("secret-key", "root-key", digest);
    try verifyDigestSignature("secret-key", digest, sig);
    try std.testing.expectError(error.SignatureMismatch, verifyDigestSignature("wrong", digest, sig));
}

test "trust registry gate" {
    var reg = TrustRegistry.init(std.testing.allocator);
    defer reg.deinit();

    const sig = Signature{ .key_id = "root-key", .value = 1 };
    try std.testing.expectError(error.UntrustedKey, verifyTrusted(&reg, sig));
    try reg.addTrustedKey("root-key");
    try verifyTrusted(&reg, sig);
}
