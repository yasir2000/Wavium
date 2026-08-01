const contract = @import("../entry/contract.zig");
const reset = @import("../reset/aarch64.zig");

pub fn buildHandoff() contract.BootError!contract.BootHandoff {
    const stage = reset.prepareResetStage();
    try reset.validateResetStage(stage);

    const handoff: contract.BootHandoff = .{
        .arch = .aarch64,
        .stack_top = 0x0000_0000_0080_0000,
        .runtime_entry = 0x0000_0000_0008_4000,
        .dtb_address = 0x0000_0000_0040_0000,
        .runtime_abi = .{
            .arg0 = 0x0000_0000_0040_0000,
            .arg1 = 0,
            .arg2 = 0,
            .arg3 = 0,
        },
        .control_state = .{
            .x86_64_cr3 = 0,
            .aarch64_ttbr0_el1 = 0x0000_0000_0010_0000,
            .riscv64_satp = 0,
        },
        .memory_regions = .{
            .{ .base = 0x0000_0000, .length = 0x0004_0000, .kind = .reserved },
            .{ .base = 0x0004_0000, .length = 0x0004_0000, .kind = .boot },
            .{ .base = 0x0008_0000, .length = 0x01F8_0000, .kind = .runtime },
            .{ .base = 0, .length = 0, .kind = .reserved },
        },
        .memory_region_count = 3,
    };

    try handoff.validate();
    return handoff;
}
