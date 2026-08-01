const contract = @import("../entry/contract.zig");

pub const CpuInitContract = struct {
    arch: contract.BootArch,
    control_register_name: []const u8,
    control_register_reset_value: u64,
    stack_pointer_register: []const u8,
    interrupts_masked_at_init: bool,
};

pub const CpuCapabilityReport = struct {
    arch: contract.BootArch,
    supports_mmu: bool,
    supports_cache_control: bool,
    supports_interrupt_masking: bool,
};

pub fn cpuInitContractForArch(arch: contract.BootArch) CpuInitContract {
    return switch (arch) {
        .x86_64 => .{
            .arch = .x86_64,
            .control_register_name = "cr0",
            .control_register_reset_value = 0x6000_0011,
            .stack_pointer_register = "rsp",
            .interrupts_masked_at_init = true,
        },
        .aarch64 => .{
            .arch = .aarch64,
            .control_register_name = "sctlr_el1",
            .control_register_reset_value = 0x0000_0000_3050_0800,
            .stack_pointer_register = "sp",
            .interrupts_masked_at_init = true,
        },
        .riscv64 => .{
            .arch = .riscv64,
            .control_register_name = "mstatus",
            .control_register_reset_value = 0x0000_0000_0000_1800,
            .stack_pointer_register = "sp",
            .interrupts_masked_at_init = true,
        },
    };
}

pub fn capabilityReportForArch(arch: contract.BootArch) CpuCapabilityReport {
    return .{
        .arch = arch,
        .supports_mmu = true,
        .supports_cache_control = true,
        .supports_interrupt_masking = true,
    };
}

pub fn validateCpuInitContract(init: CpuInitContract) contract.BootError!void {
    if (!init.interrupts_masked_at_init) {
        return error.InvalidResetState;
    }
    if (init.control_register_name.len == 0 or init.stack_pointer_register.len == 0) {
        return error.InvalidResetState;
    }
}
