const std = @import("std");

/// Inter-processor communication: architecture-abstracted IPI dispatch
/// (x86 APIC / ARM GIC / RISC-V CLINT+SBI) plus the higher-level
/// send/broadcast/multicast/barrier primitives every cross-core
/// notification in this runtime is built from - remote actor wake-up,
/// cross-core scheduling, cross-core memory synchronization, and remote
/// mailbox notification are all just different `IpiVector`s carried over
/// the same transport.
pub fn moduleName() []const u8 {
    return "wavium-ipi";
}

pub const arch = @import("arch.zig");
pub const vector = @import("vector.zig");
pub const transport = @import("transport.zig");
pub const barrier = @import("barrier.zig");
pub const benchmark = @import("benchmark.zig");

test "moduleName" {
    try std.testing.expectEqualStrings("wavium-ipi", moduleName());
}

var wakes_delivered: usize = 0;
var mailbox_notifies_delivered: usize = 0;

fn deliver(_: arch.CoreId, ipi_vector: u8) bool {
    if (ipi_vector == @intFromEnum(vector.IpiVector.wake)) wakes_delivered += 1;
    if (ipi_vector == @intFromEnum(vector.IpiVector.mailbox_notify)) mailbox_notifies_delivered += 1;
    return true;
}

test "end-to-end: remote wake-up, mailbox notification, and a cross-core barrier" {
    wakes_delivered = 0;
    mailbox_notifies_delivered = 0;

    const t = transport.Transport{
        .backend = .{ .arch = .riscv_clint_sbi, .send_fn = deliver },
        .local_core = 0,
    };

    // Remote actor wake-up: core 0 wakes core 2.
    try t.send(2, .wake);
    try std.testing.expectEqual(@as(usize, 1), wakes_delivered);

    // Remote mailbox notification fanned out via multicast.
    try t.multicast((1 << 1) | (1 << 2), .mailbox_notify);
    try std.testing.expectEqual(@as(usize, 2), mailbox_notifies_delivered);

    // Cross-core memory synchronization: a barrier releases only once
    // every participating core has arrived.
    var b = barrier.Barrier.init(3);
    try std.testing.expect(!b.arrive());
    try std.testing.expect(!b.arrive());
    try std.testing.expect(b.arrive());
    try std.testing.expect(b.isReleased());
}
