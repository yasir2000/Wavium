const std = @import("std");

/// Runtime-managed Symmetric Multi-Processing (SMP) framework: boots every
/// CPU core with no operating system, no kernel-owned scheduler, and no
/// POSIX threads involved. See docs/images/smp-architecture-prompt16.mmd
/// for the boot/startup architecture diagram.
pub fn moduleName() []const u8 {
    return "wavium-smp";
}

pub const core = @import("core.zig");
pub const topology = @import("topology.zig");
pub const cpu = @import("cpu.zig");
pub const startup = @import("startup.zig");
pub const boot = @import("boot.zig");
pub const ipi = @import("ipi.zig");

fn fakeStart(id: core.CoreId) startup.StartupError!void {
    _ = id;
}

fn fakeIpiSend(msg: ipi.IpiMessage) ipi.IpiError!void {
    _ = msg;
}

test "moduleName" {
    try std.testing.expectEqualStrings("wavium-smp", moduleName());
}

test "end-to-end: bootstrap, detect topology, start secondaries, assign affinity, wake via IPI" {
    // 1. Bring up the bootstrap processor and register 8 logical cores.
    var registry = try boot.initBootstrap(8);
    try std.testing.expectEqual(@as(usize, 1), registry.onlineCount());

    // 2. Detect topology: 2 sockets of 4 cores each, no SMT.
    const topo = try topology.detect(8, 4, 1);
    try std.testing.expectEqual(@as(usize, 2), topo.socketCount());

    // 3. Start every secondary (Application Processor) core.
    const launcher = startup.SecondaryLauncher{ .start_fn = fakeStart };
    const started = boot.startAllSecondaries(&registry, launcher);
    try std.testing.expectEqual(@as(usize, 7), started);
    try std.testing.expectEqual(@as(usize, 8), registry.onlineCount());

    // 4. Build a CPU affinity mask restricted to socket 0's cores.
    var affinity = cpu.CpuAffinity.none();
    for (0..8) |i| {
        const id: core.CoreId = @intCast(i);
        const entry = topo.get(id) orelse unreachable;
        if (entry.socket_id == 0) affinity = affinity.withCore(id);
    }
    try std.testing.expectEqual(@as(u32, 4), affinity.coreCount());
    try std.testing.expect(affinity.allows(0));
    try std.testing.expect(!affinity.allows(4));

    // 5. Wake a core via the IPI seam.
    const sender = ipi.IpiSender{ .send_fn = fakeIpiSend };
    try sender.wake(0, 1);

    // 6. Hotplug: take a core offline, then bring it back online.
    try registry.setState(3, .halted);
    try std.testing.expectEqual(@as(usize, 7), registry.onlineCount());
    try registry.setState(3, .offline);
    try launcher.launch(&registry, 3);
    try std.testing.expectEqual(@as(usize, 8), registry.onlineCount());
}
