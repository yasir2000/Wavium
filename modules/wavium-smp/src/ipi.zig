const std = @import("std");
const core_mod = @import("core.zig");

pub const IpiKind = enum(u8) {
    wake,
    halt,
};

pub const IpiMessage = struct {
    from: core_mod.CoreId,
    to: core_mod.CoreId,
    kind: IpiKind,
};

pub const IpiError = error{
    SendFailed,
};

/// Decoupling seam over the architecture-specific interrupt-controller send
/// primitive (x86_64 local APIC ICR write, ARM64 GIC SGI, RISC-V IPI CSR /
/// SBI call). The SMP framework never issues the raw signal itself; callers
/// bind a `SendFn`. Full inter-processor messaging semantics (mailboxes,
/// broadcast, TLB shootdown, etc.) are built out in the dedicated IPC/IPI
/// milestone - this seam only covers the minimal wake/halt signal needed to
/// bring secondary cores online and take them back offline.
pub const SendFn = *const fn (msg: IpiMessage) IpiError!void;

pub const IpiSender = struct {
    send_fn: SendFn,

    pub fn wake(self: IpiSender, from: core_mod.CoreId, to: core_mod.CoreId) IpiError!void {
        return self.send_fn(.{ .from = from, .to = to, .kind = .wake });
    }

    pub fn halt(self: IpiSender, from: core_mod.CoreId, to: core_mod.CoreId) IpiError!void {
        return self.send_fn(.{ .from = from, .to = to, .kind = .halt });
    }
};

var test_last_message: ?IpiMessage = null;

fn testSendOk(msg: IpiMessage) IpiError!void {
    test_last_message = msg;
}

fn testSendFails(msg: IpiMessage) IpiError!void {
    _ = msg;
    return error.SendFailed;
}

test "IpiSender.wake delivers a wake message" {
    test_last_message = null;
    const sender = IpiSender{ .send_fn = testSendOk };
    try sender.wake(0, 1);

    const msg = test_last_message orelse unreachable;
    try std.testing.expectEqual(@as(core_mod.CoreId, 0), msg.from);
    try std.testing.expectEqual(@as(core_mod.CoreId, 1), msg.to);
    try std.testing.expectEqual(IpiKind.wake, msg.kind);
}

test "IpiSender.halt delivers a halt message" {
    test_last_message = null;
    const sender = IpiSender{ .send_fn = testSendOk };
    try sender.halt(2, 3);

    const msg = test_last_message orelse unreachable;
    try std.testing.expectEqual(IpiKind.halt, msg.kind);
}

test "IpiSender propagates send failures" {
    const sender = IpiSender{ .send_fn = testSendFails };
    try std.testing.expectError(error.SendFailed, sender.wake(0, 1));
}
