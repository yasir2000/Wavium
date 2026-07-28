const std = @import("std");
const comp_tools = @import("wavium-component-tools");
const build = @import("wavium-build");
const sec_tools = @import("wavium-security-tools");

test "component-tools create inspect compose sign with build package" {
    const descriptor = try comp_tools.componentCreate("billing", "runtime");
    const composed = try comp_tools.componentCompose(descriptor, 1);
    try std.testing.expectEqualStrings("billing", composed.name);

    const wasm_bytes = [_]u8{ 0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00 };
    const inspected = try comp_tools.componentInspect(wasm_bytes[0..]);
    try std.testing.expect(inspected.valid_magic);

    const artifact = try build.componentBuild(.{
        .source_path = "components/billing/src/lib.rs",
        .component_name = descriptor.name,
        .wit_world = descriptor.wit_world,
        .target = .wasm32_component,
    });

    const deps = [_][]const u8{"wasi:clocks@0.2"};
    const caps = [_][]const u8{"storage.read"};
    const manifest = build.WvmManifest{
        .package_name = "billing.wvm",
        .component_name = descriptor.name,
        .wit_world = descriptor.wit_world,
        .target = .wasm32_component,
        .dependencies = deps[0..],
        .capabilities = caps[0..],
        .signature_present = true,
    };

    const pkg = try build.packageArtifact(artifact, manifest);

    const intent = try comp_tools.componentSignIntent(descriptor.name, "root-key");
    try std.testing.expectEqualStrings("root-key", intent.key_id);

    const sig = try sec_tools.signDigest("tool-key", intent.key_id, pkg.component_digest);
    try sec_tools.verifyDigestSignature("tool-key", pkg.component_digest, sig);
}
