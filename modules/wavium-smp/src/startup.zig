const std = @import("std");
const core_mod = @import("core.zig");

pub const StartupError = core_mod.CoreError || error{StartFailed};

/// Decoupling seam: the SMP framework never issues the actual low-level
/// wake sequence itself (x86_64 INIT-SIPI-SIPI, ARM64 PSCI CPU_ON, RISC-V
/// SBI HSM hart_start). Callers bind a `StartFn` that performs the
/// architecture-specific wake and reports success/failure.
pub const StartFn = *const fn (id: core_mod.CoreId) StartupError!void;

pub const SecondaryLauncher = struct {
    start_fn: StartFn,

    /// Transitions a core offline -> starting -> online, invoking the bound
    /// low-level start function between the two transitions. On failure the
    /// core is left `.offline` so it can be retried later (CPU hotplug
    /// abstraction).
    pub fn launch(self: SecondaryLauncher, registry: *core_mod.CoreRegistry, id: core_mod.CoreId) !void {
        try registry.setState(id, .starting);
        self.start_fn(id) catch |err| {
            registry.setState(id, .offline) catch {};
            return err;
        };
        try registry.setState(id, .online);
    }
};

fn fakeStartOk(id: core_mod.CoreId) StartupError!void {
    _ = id;
}

fn fakeStartFails(id: core_mod.CoreId) StartupError!void {
    _ = id;
    return error.StartFailed;
}

test "SecondaryLauncher brings a core online on success" {
    var reg = core_mod.CoreRegistry.init();
    try reg.register(0, true);
    try reg.register(1, false);
    try reg.setState(0, .starting);
    try reg.setState(0, .online);

    const launcher = SecondaryLauncher{ .start_fn = fakeStartOk };
    try launcher.launch(&reg, 1);

    const info = reg.find(1) orelse unreachable;
    try std.testing.expectEqual(core_mod.CoreState.online, info.state);
}

test "SecondaryLauncher leaves core offline (retryable) on failure" {
    var reg = core_mod.CoreRegistry.init();
    try reg.register(0, true);

    const launcher = SecondaryLauncher{ .start_fn = fakeStartFails };
    try std.testing.expectError(error.StartFailed, launcher.launch(&reg, 0));

    const info = reg.find(0) orelse unreachable;
    try std.testing.expectEqual(core_mod.CoreState.offline, info.state);

    // hotplug retry: the same core can be launched again after a failure
    const retry_launcher = SecondaryLauncher{ .start_fn = fakeStartOk };
    try retry_launcher.launch(&reg, 0);
    try std.testing.expectEqual(core_mod.CoreState.online, (reg.find(0) orelse unreachable).state);
}
