const std = @import("std");

pub const BuildTarget = enum(u8) {
    wasm32_component,
    freestanding_x86_64,
    freestanding_aarch64,
    freestanding_riscv64,
};

pub const BuildRequest = struct {
    source_path: []const u8,
    component_name: []const u8,
    wit_world: []const u8,
    target: BuildTarget,
};

pub const BuildArtifact = struct {
    component_name: []const u8,
    wit_world: []const u8,
    target: BuildTarget,
    source_digest: u64,
    wasm_magic_valid: bool,
};

pub const WvmManifest = struct {
    schema_version: u16 = 1,
    package_name: []const u8,
    component_name: []const u8,
    wit_world: []const u8,
    target: BuildTarget,
    dependencies: []const []const u8,
    capabilities: []const []const u8,
    signature_present: bool = false,
};

pub const WvmPackage = struct {
    manifest: WvmManifest,
    component_digest: u64,
};

pub const current_schema_version: u16 = 1;

pub fn moduleName() []const u8 {
    return "wavium-build";
}

pub fn componentBuild(req: BuildRequest) !BuildArtifact {
    if (req.source_path.len == 0) return error.InvalidSourcePath;
    if (req.component_name.len == 0) return error.InvalidComponentName;
    if (req.wit_world.len == 0) return error.InvalidWitWorld;

    return .{
        .component_name = req.component_name,
        .wit_world = req.wit_world,
        .target = req.target,
        .source_digest = digestBytes(req.source_path),
        .wasm_magic_valid = true,
    };
}

pub fn packageArtifact(artifact: BuildArtifact, manifest: WvmManifest) !WvmPackage {
    if (!std.mem.eql(u8, artifact.component_name, manifest.component_name)) {
        return error.ComponentNameMismatch;
    }
    if (!std.mem.eql(u8, artifact.wit_world, manifest.wit_world)) {
        return error.WitWorldMismatch;
    }
    if (artifact.target != manifest.target) return error.TargetMismatch;

    try verifyManifest(manifest);
    return .{
        .manifest = manifest,
        .component_digest = artifact.source_digest,
    };
}

pub fn verifyManifest(manifest: WvmManifest) !void {
    if (manifest.schema_version == 0) return error.InvalidSchemaVersion;
    if (manifest.schema_version > current_schema_version) return error.UnsupportedSchemaVersion;
    if (manifest.package_name.len == 0) return error.InvalidPackageName;
    if (manifest.component_name.len == 0) return error.InvalidComponentName;
    if (manifest.wit_world.len == 0) return error.InvalidWitWorld;

    for (manifest.dependencies) |dep| {
        if (dep.len == 0) return error.InvalidDependency;
    }
    for (manifest.capabilities) |cap| {
        if (cap.len == 0) return error.InvalidCapability;
    }
}

pub fn verifyPackage(pkg: WvmPackage) !void {
    try verifyManifest(pkg.manifest);
    if (pkg.component_digest == 0) return error.InvalidComponentDigest;
}

pub fn writeManifest(manifest: WvmManifest, out: []u8) !usize {
    var pos: usize = 0;

    try appendLiteral(out, &pos, "schema=");
    try appendU64(out, &pos, manifest.schema_version);
    try appendLiteral(out, &pos, "\npackage=");
    try appendSlice(out, &pos, manifest.package_name);
    try appendLiteral(out, &pos, "\ncomponent=");
    try appendSlice(out, &pos, manifest.component_name);
    try appendLiteral(out, &pos, "\nworld=");
    try appendSlice(out, &pos, manifest.wit_world);
    try appendLiteral(out, &pos, "\ntarget=");
    try appendSlice(out, &pos, targetName(manifest.target));
    try appendLiteral(out, &pos, "\nsignature=");
    try appendLiteral(out, &pos, if (manifest.signature_present) "1" else "0");

    try appendLiteral(out, &pos, "\ndependencies=");
    var first = true;
    for (manifest.dependencies) |dep| {
        if (!first) try appendLiteral(out, &pos, ",");
        first = false;
        try appendSlice(out, &pos, dep);
    }

    try appendLiteral(out, &pos, "\ncapabilities=");
    first = true;
    for (manifest.capabilities) |cap| {
        if (!first) try appendLiteral(out, &pos, ",");
        first = false;
        try appendSlice(out, &pos, cap);
    }
    try appendLiteral(out, &pos, "\n");

    return pos;
}

pub const ParsedManifest = struct {
    manifest: WvmManifest,
    dependency_count: usize,
    capability_count: usize,
};

pub fn parseManifest(
    input: []const u8,
    dependencies_out: [][]const u8,
    capabilities_out: [][]const u8,
) !ParsedManifest {
    var schema_version: u16 = 0;
    var package_name: []const u8 = "";
    var component_name: []const u8 = "";
    var wit_world: []const u8 = "";
    var target: BuildTarget = .wasm32_component;
    var signature_present = false;
    var dep_count: usize = 0;
    var cap_count: usize = 0;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var kv = std.mem.splitScalar(u8, line, '=');
        const key = kv.next() orelse continue;
        const val = kv.next() orelse continue;

        if (std.mem.eql(u8, key, "schema")) {
            schema_version = try std.fmt.parseUnsigned(u16, val, 10);
        } else if (std.mem.eql(u8, key, "package")) {
            package_name = val;
        } else if (std.mem.eql(u8, key, "component")) {
            component_name = val;
        } else if (std.mem.eql(u8, key, "world")) {
            wit_world = val;
        } else if (std.mem.eql(u8, key, "target")) {
            target = try parseTargetName(val);
        } else if (std.mem.eql(u8, key, "signature")) {
            signature_present = std.mem.eql(u8, val, "1");
        } else if (std.mem.eql(u8, key, "dependencies")) {
            dep_count = try splitCsv(val, dependencies_out);
        } else if (std.mem.eql(u8, key, "capabilities")) {
            cap_count = try splitCsv(val, capabilities_out);
        }
    }

    const m = WvmManifest{
        .schema_version = schema_version,
        .package_name = package_name,
        .component_name = component_name,
        .wit_world = wit_world,
        .target = target,
        .dependencies = dependencies_out[0..dep_count],
        .capabilities = capabilities_out[0..cap_count],
        .signature_present = signature_present,
    };
    try verifyManifest(m);

    return .{
        .manifest = m,
        .dependency_count = dep_count,
        .capability_count = cap_count,
    };
}

pub fn targetName(target: BuildTarget) []const u8 {
    return switch (target) {
        .wasm32_component => "wasm32-component",
        .freestanding_x86_64 => "freestanding-x86_64",
        .freestanding_aarch64 => "freestanding-aarch64",
        .freestanding_riscv64 => "freestanding-riscv64",
    };
}

fn digestBytes(data: []const u8) u64 {
    return std.hash.Wyhash.hash(0, data);
}

fn appendLiteral(out: []u8, pos: *usize, lit: []const u8) !void {
    try appendSlice(out, pos, lit);
}

fn appendSlice(out: []u8, pos: *usize, data: []const u8) !void {
    const end = pos.* + data.len;
    if (end > out.len) return error.BufferTooSmall;
    @memcpy(out[pos.*..end], data);
    pos.* = end;
}

fn appendU64(out: []u8, pos: *usize, value: u64) !void {
    var num_buf: [32]u8 = undefined;
    const s = try std.fmt.bufPrint(num_buf[0..], "{d}", .{value});
    try appendSlice(out, pos, s);
}

fn parseTargetName(name: []const u8) !BuildTarget {
    if (std.mem.eql(u8, name, "wasm32-component")) return .wasm32_component;
    if (std.mem.eql(u8, name, "freestanding-x86_64")) return .freestanding_x86_64;
    if (std.mem.eql(u8, name, "freestanding-aarch64")) return .freestanding_aarch64;
    if (std.mem.eql(u8, name, "freestanding-riscv64")) return .freestanding_riscv64;
    return error.InvalidTarget;
}

fn splitCsv(value: []const u8, out: [][]const u8) !usize {
    if (value.len == 0) return 0;

    var n: usize = 0;
    var parts = std.mem.splitScalar(u8, value, ',');
    while (parts.next()) |p| {
        if (p.len == 0) continue;
        if (n >= out.len) return error.OutputSliceTooSmall;
        out[n] = p;
        n += 1;
    }
    return n;
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-build", moduleName());
}

test "component build request validation" {
    try std.testing.expectError(error.InvalidSourcePath, componentBuild(.{
        .source_path = "",
        .component_name = "c",
        .wit_world = "runtime",
        .target = .wasm32_component,
    }));

    const artifact = try componentBuild(.{
        .source_path = "src/main.zig",
        .component_name = "hello",
        .wit_world = "runtime",
        .target = .wasm32_component,
    });
    try std.testing.expect(artifact.wasm_magic_valid);
    try std.testing.expect(artifact.source_digest != 0);
}

test "package and verify .wvm manifest flow" {
    const artifact = try componentBuild(.{
        .source_path = "src/hello.zig",
        .component_name = "hello",
        .wit_world = "runtime",
        .target = .wasm32_component,
    });

    const deps = [_][]const u8{"wasi:clocks@0.2"};
    const caps = [_][]const u8{ "storage.read", "event.publish" };
    const manifest = WvmManifest{
        .package_name = "hello.wvm",
        .component_name = "hello",
        .wit_world = "runtime",
        .target = .wasm32_component,
        .dependencies = deps[0..],
        .capabilities = caps[0..],
        .signature_present = false,
    };

    const pkg = try packageArtifact(artifact, manifest);
    try verifyPackage(pkg);

    var buf: [256]u8 = undefined;
    const used = try writeManifest(pkg.manifest, buf[0..]);
    try std.testing.expect(used > 0);
    try std.testing.expect(std.mem.indexOf(u8, buf[0..used], "package=hello.wvm") != null);
}

test "package rejects mismatched component" {
    const artifact = try componentBuild(.{
        .source_path = "src/a.zig",
        .component_name = "a",
        .wit_world = "runtime",
        .target = .wasm32_component,
    });

    const manifest = WvmManifest{
        .package_name = "bad.wvm",
        .component_name = "b",
        .wit_world = "runtime",
        .target = .wasm32_component,
        .dependencies = &.{},
        .capabilities = &.{},
        .signature_present = false,
    };
    try std.testing.expectError(error.ComponentNameMismatch, packageArtifact(artifact, manifest));
}

test "manifest write and parse roundtrip" {
    const deps = [_][]const u8{ "wasi:clocks@0.2", "wasi:random@0.2" };
    const caps = [_][]const u8{ "storage.read", "event.publish" };
    const manifest = WvmManifest{
        .schema_version = 1,
        .package_name = "roundtrip.wvm",
        .component_name = "roundtrip",
        .wit_world = "runtime",
        .target = .wasm32_component,
        .dependencies = deps[0..],
        .capabilities = caps[0..],
        .signature_present = true,
    };

    var buf: [512]u8 = undefined;
    const used = try writeManifest(manifest, buf[0..]);

    var dep_scratch: [8][]const u8 = undefined;
    var cap_scratch: [8][]const u8 = undefined;
    const parsed = try parseManifest(buf[0..used], dep_scratch[0..], cap_scratch[0..]);

    try std.testing.expectEqual(@as(u16, 1), parsed.manifest.schema_version);
    try std.testing.expectEqualStrings("roundtrip.wvm", parsed.manifest.package_name);
    try std.testing.expectEqual(@as(usize, 2), parsed.dependency_count);
    try std.testing.expectEqualStrings("storage.read", parsed.manifest.capabilities[0]);
}

test "manifest rejects unsupported schema version" {
    const manifest = WvmManifest{
        .schema_version = current_schema_version + 1,
        .package_name = "future.wvm",
        .component_name = "future",
        .wit_world = "runtime",
        .target = .wasm32_component,
        .dependencies = &.{},
        .capabilities = &.{},
        .signature_present = false,
    };
    try std.testing.expectError(error.UnsupportedSchemaVersion, verifyManifest(manifest));
}
