const std = @import("std");
const build = @import("wavium-build");
const sec_tools = @import("wavium-security-tools");

test "build package and verify with trust/signature gate" {
    const artifact = try build.componentBuild(.{
        .source_path = "src/payment.zig",
        .component_name = "payment",
        .wit_world = "runtime",
        .target = .wasm32_component,
    });

    const deps = [_][]const u8{"wasi:clocks@0.2"};
    const caps = [_][]const u8{ "storage.read", "storage.write" };
    const manifest = build.WvmManifest{
        .package_name = "payment.wvm",
        .component_name = "payment",
        .wit_world = "runtime",
        .target = .wasm32_component,
        .dependencies = deps[0..],
        .capabilities = caps[0..],
        .signature_present = true,
    };

    const pkg = try build.packageArtifact(artifact, manifest);
    try build.verifyPackage(pkg);

    const sig = try sec_tools.signDigest("supply-chain-key", "root-key", pkg.component_digest);
    try sec_tools.verifyDigestSignature("supply-chain-key", pkg.component_digest, sig);

    var trust = sec_tools.TrustRegistry.init(std.testing.allocator);
    defer trust.deinit();

    try std.testing.expectError(error.UntrustedKey, sec_tools.verifyTrusted(&trust, sig));
    try trust.addTrustedKey("root-key");
    try sec_tools.verifyTrusted(&trust, sig);
}
