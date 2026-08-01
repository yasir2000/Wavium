const std = @import("std");

/// Which interrupt-controller family this core's IPI backend targets.
/// `send_fn` is the actual arch-specific trigger (x86 APIC ICR write, ARM
/// GIC SGI generation, or RISC-V CLINT MSIP / SBI `sbi_send_ipi`) - this
/// module never issues those instructions itself, keeping it portable
/// across all three (same function-pointer decoupling pattern used
/// throughout this codebase for ExecutionBackend/DriverLifecycle/StartFn).
pub const IpiArch = enum {
    x86_apic,
    arm_gic,
    riscv_clint_sbi,
};

pub const CoreId = u16;

pub const SendError = error{SendFailed};

pub const SendFn = *const fn (target_core: CoreId, vector: u8) bool;

/// Architecture-abstracted low-level IPI dispatcher: one physical
/// interrupt "send" primitive per target core, regardless of which
/// interrupt controller is underneath.
pub const ArchBackend = struct {
    arch: IpiArch,
    send_fn: SendFn,

    pub fn send(self: ArchBackend, target_core: CoreId, vector: u8) SendError!void {
        if (!self.send_fn(target_core, vector)) return error.SendFailed;
    }
};

test "ArchBackend.send delegates to the bound send_fn and surfaces failure" {
    const Ok = struct {
        fn call(_: CoreId, _: u8) bool {
            return true;
        }
    };
    const Fail = struct {
        fn call(_: CoreId, _: u8) bool {
            return false;
        }
    };

    const ok_backend = ArchBackend{ .arch = .x86_apic, .send_fn = Ok.call };
    try ok_backend.send(1, 0);

    const fail_backend = ArchBackend{ .arch = .arm_gic, .send_fn = Fail.call };
    try std.testing.expectError(error.SendFailed, fail_backend.send(1, 0));
}
