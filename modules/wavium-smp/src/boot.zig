const std = @import("std");
const core_mod = @import("core.zig");
const startup = @import("startup.zig");

pub const BootError = core_mod.CoreError;

/// Bootstrap Processor (BSP) initialization. Registers `core_count` logical
/// cores - core 0 as the bootstrap processor (brought online immediately,
/// no OS/kernel handoff involved) and the remaining cores as offline
/// Application Processors awaiting `startAllSecondaries`.
pub fn initBootstrap(core_count: usize) BootError!core_mod.CoreRegistry {
    var registry = core_mod.CoreRegistry.init();

    var i: usize = 0;
    while (i < core_count) : (i += 1) {
        try registry.register(@intCast(i), i == 0);
    }

    if (core_count > 0) {
        try registry.setState(0, .starting);
        try registry.setState(0, .online);
    }

    return registry;
}

/// Starts every registered secondary (non-bootstrap) core using the given
/// launcher. Continues past individual core failures (a failed AP is left
/// `.offline` for a later hotplug retry) and returns the number of cores
/// that successfully came online.
pub fn startAllSecondaries(registry: *core_mod.CoreRegistry, launcher: startup.SecondaryLauncher) usize {
    var started: usize = 0;
    var i: usize = 0;
    while (i < registry.count) : (i += 1) {
        const c = registry.cores[i];
        if (c.is_bootstrap) continue;
        launcher.launch(registry, c.id) catch continue;
        started += 1;
    }
    return started;
}

fn fakeStartOk(id: core_mod.CoreId) startup.StartupError!void {
    _ = id;
}

fn fakeStartFailsOnCore2(id: core_mod.CoreId) startup.StartupError!void {
    if (id == 2) return error.StartFailed;
}

test "initBootstrap brings up core 0 and leaves the rest offline" {
    var reg = try initBootstrap(4);
    try std.testing.expectEqual(@as(usize, 4), reg.count);
    try std.testing.expectEqual(@as(usize, 1), reg.onlineCount());

    const bsp = reg.find(0) orelse unreachable;
    try std.testing.expect(bsp.is_bootstrap);
    try std.testing.expectEqual(core_mod.CoreState.online, bsp.state);

    const ap = reg.find(1) orelse unreachable;
    try std.testing.expect(!ap.is_bootstrap);
    try std.testing.expectEqual(core_mod.CoreState.offline, ap.state);
}

test "startAllSecondaries brings up every non-bootstrap core" {
    var reg = try initBootstrap(4);
    const launcher = startup.SecondaryLauncher{ .start_fn = fakeStartOk };
    const started = startAllSecondaries(&reg, launcher);

    try std.testing.expectEqual(@as(usize, 3), started);
    try std.testing.expectEqual(@as(usize, 4), reg.onlineCount());
}

test "startAllSecondaries continues past individual core failures" {
    var reg = try initBootstrap(4);
    const launcher = startup.SecondaryLauncher{ .start_fn = fakeStartFailsOnCore2 };
    const started = startAllSecondaries(&reg, launcher);

    try std.testing.expectEqual(@as(usize, 2), started);
    try std.testing.expectEqual(core_mod.CoreState.offline, (reg.find(2) orelse unreachable).state);
    try std.testing.expectEqual(core_mod.CoreState.online, (reg.find(1) orelse unreachable).state);
    try std.testing.expectEqual(core_mod.CoreState.online, (reg.find(3) orelse unreachable).state);
}
