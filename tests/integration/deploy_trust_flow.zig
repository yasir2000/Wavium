const std = @import("std");
const build = @import("wavium-build");
const sec_tools = @import("wavium-security-tools");
const deploy = @import("wavium-deploy");

const TrustContext = struct {
    key_material: []const u8,
    signature: sec_tools.Signature,
};

fn verifyTrust(ctx_ptr: *const anyopaque, digest: u64) bool {
    const ctx: *const TrustContext = @ptrCast(@alignCast(ctx_ptr));
    sec_tools.verifyDigestSignature(ctx.key_material, digest, ctx.signature) catch return false;
    return true;
}

test "build-sign-verify-deploy trust gate" {
    const artifact = try build.componentBuild(.{
        .source_path = "src/deploy.zig",
        .component_name = "deployable",
        .wit_world = "runtime",
        .target = .wasm32_component,
    });

    const manifest = build.WvmManifest{
        .package_name = "deployable.wvm",
        .component_name = "deployable",
        .wit_world = "runtime",
        .target = .wasm32_component,
        .dependencies = &.{},
        .capabilities = &.{"storage.read"},
        .signature_present = true,
    };

    const pkg = try build.packageArtifact(artifact, manifest);

    const sig = try sec_tools.signDigest("deploy-key", "root-key", pkg.component_digest);
    var trust = sec_tools.TrustRegistry.init(std.testing.allocator);
    defer trust.deinit();
    try trust.addTrustedKey("root-key");
    try sec_tools.verifyTrusted(&trust, sig);

    var mgr = deploy.DeployManager.init(std.testing.allocator);
    defer mgr.deinit();

    const trust_ctx = TrustContext{ .key_material = "deploy-key", .signature = sig };
    try mgr.deploy(.{
        .package_name = pkg.manifest.package_name,
        .package_digest = pkg.component_digest,
        .target = .edge_node,
        .node_id = "edge-prod-1",
        .version = 1,
    }, @ptrCast(&trust_ctx), verifyTrust);

    const tampered_ctx = TrustContext{ .key_material = "wrong-key", .signature = sig };
    try std.testing.expectError(error.UntrustedPackage, mgr.update(.{
        .package_name = pkg.manifest.package_name,
        .package_digest = pkg.component_digest,
        .target = .edge_node,
        .node_id = "edge-prod-1",
        .version = 2,
    }, @ptrCast(&tampered_ctx), verifyTrust));
}
