const std = @import("std");

pub const DeploymentTarget = enum {
    bare_metal,
    embedded,
    edge_node,
    cloud_node,
};

pub const DeployPlan = struct {
    package_name: []const u8,
    package_digest: u64,
    target: DeploymentTarget,
    node_id: []const u8,
    version: u32,
};

pub const DeployAction = enum {
    deploy,
    update,
    rollback,
    migrate,
};

pub const DeployRecord = struct {
    action: DeployAction,
    package_name: []const u8,
    version: u32,
};

pub const VerifyTrustFn = *const fn (ctx: *const anyopaque, package_digest: u64) bool;

pub const DeployManager = struct {
    allocator: std.mem.Allocator,
    history: std.ArrayListUnmanaged(DeployRecord),

    pub fn init(allocator: std.mem.Allocator) DeployManager {
        return .{ .allocator = allocator, .history = .empty };
    }

    pub fn deinit(self: *DeployManager) void {
        self.history.deinit(self.allocator);
    }

    pub fn deploy(
        self: *DeployManager,
        plan: DeployPlan,
        trust_ctx: *const anyopaque,
        verify_trust: VerifyTrustFn,
    ) !void {
        try validatePlan(plan);
        if (!verify_trust(trust_ctx, plan.package_digest)) return error.UntrustedPackage;
        try self.history.append(self.allocator, .{ .action = .deploy, .package_name = plan.package_name, .version = plan.version });
    }

    pub fn update(
        self: *DeployManager,
        plan: DeployPlan,
        trust_ctx: *const anyopaque,
        verify_trust: VerifyTrustFn,
    ) !void {
        try validatePlan(plan);
        if (!verify_trust(trust_ctx, plan.package_digest)) return error.UntrustedPackage;
        try self.history.append(self.allocator, .{ .action = .update, .package_name = plan.package_name, .version = plan.version });
    }

    pub fn rollback(self: *DeployManager, package_name: []const u8, version: u32) !void {
        if (package_name.len == 0) return error.InvalidPackageName;
        if (version == 0) return error.InvalidVersion;
        try self.history.append(self.allocator, .{ .action = .rollback, .package_name = package_name, .version = version });
    }

    pub fn migrate(
        self: *DeployManager,
        plan: DeployPlan,
        trust_ctx: *const anyopaque,
        verify_trust: VerifyTrustFn,
    ) !void {
        try validatePlan(plan);
        if (!verify_trust(trust_ctx, plan.package_digest)) return error.UntrustedPackage;
        try self.history.append(self.allocator, .{ .action = .migrate, .package_name = plan.package_name, .version = plan.version });
    }

    pub fn latest(self: *DeployManager) ?DeployRecord {
        if (self.history.items.len == 0) return null;
        return self.history.items[self.history.items.len - 1];
    }
};

pub fn moduleName() []const u8 {
    return "wavium-deploy";
}

pub fn validatePlan(plan: DeployPlan) !void {
    if (plan.package_name.len == 0) return error.InvalidPackageName;
    if (plan.package_digest == 0) return error.InvalidPackageDigest;
    if (plan.node_id.len == 0) return error.InvalidNodeId;
    if (plan.version == 0) return error.InvalidVersion;
}

fn alwaysTrust(_: *const anyopaque, _: u64) bool {
    return true;
}

fn neverTrust(_: *const anyopaque, _: u64) bool {
    return false;
}

test "module name" {
    try std.testing.expectEqualStrings("wavium-deploy", moduleName());
}

test "deploy manager trust-gated lifecycle" {
    var mgr = DeployManager.init(std.testing.allocator);
    defer mgr.deinit();

    const plan = DeployPlan{
        .package_name = "payment.wvm",
        .package_digest = 0x1234,
        .target = .edge_node,
        .node_id = "edge-1",
        .version = 1,
    };

    const trust_ctx: *const anyopaque = @ptrFromInt(1);
    try mgr.deploy(plan, trust_ctx, alwaysTrust);
    try mgr.update(.{ .package_name = "payment.wvm", .package_digest = 0x2345, .target = .edge_node, .node_id = "edge-1", .version = 2 }, trust_ctx, alwaysTrust);
    try mgr.rollback("payment.wvm", 1);
    try mgr.migrate(.{ .package_name = "payment.wvm", .package_digest = 0x2345, .target = .cloud_node, .node_id = "cloud-a", .version = 2 }, trust_ctx, alwaysTrust);

    const last = mgr.latest().?;
    try std.testing.expectEqual(DeployAction.migrate, last.action);
}

test "deploy rejects untrusted package" {
    var mgr = DeployManager.init(std.testing.allocator);
    defer mgr.deinit();

    const plan = DeployPlan{
        .package_name = "bad.wvm",
        .package_digest = 0x1234,
        .target = .edge_node,
        .node_id = "edge-2",
        .version = 1,
    };

    const trust_ctx: *const anyopaque = @ptrFromInt(2);
    try std.testing.expectError(error.UntrustedPackage, mgr.deploy(plan, trust_ctx, neverTrust));
}
