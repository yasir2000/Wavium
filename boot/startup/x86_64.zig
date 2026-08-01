const contract = @import("../entry/contract.zig");
const reset = @import("../reset/x86_64.zig");

pub const X86_64Profile = enum {
    qemu_pc,
    uefi_vm,
};

const ProfileLayout = struct {
    stack_top: u64,
    runtime_entry: u64,
    cr3: u64,
    reserved_base: u64,
    reserved_length: u64,
    boot_base: u64,
    boot_length: u64,
    runtime_base: u64,
    runtime_length: u64,
};

fn layoutForProfile(profile: X86_64Profile) ProfileLayout {
    return switch (profile) {
        .qemu_pc => .{
            .stack_top = 0x0000_0000_0008_0000,
            .runtime_entry = 0x0000_0000_0010_0000,
            .cr3 = 0x0000_0000_0009_0000,
            .reserved_base = 0x0000_0000,
            .reserved_length = 0x0000_8000,
            .boot_base = 0x0000_8000,
            .boot_length = 0x0000_8000,
            .runtime_base = 0x0001_0000,
            .runtime_length = 0x003F_0000,
        },
        .uefi_vm => .{
            .stack_top = 0x0000_0000_0020_0000,
            .runtime_entry = 0x0000_0000_0040_0000,
            .cr3 = 0x0000_0000_0030_0000,
            .reserved_base = 0x0000_0000,
            .reserved_length = 0x0001_0000,
            .boot_base = 0x0001_0000,
            .boot_length = 0x000F_0000,
            .runtime_base = 0x0010_0000,
            .runtime_length = 0x03F0_0000,
        },
    };
}

pub fn buildHandoffForProfile(profile: X86_64Profile) contract.BootError!contract.BootHandoff {
    const layout = layoutForProfile(profile);

    const handoff: contract.BootHandoff = .{
        .arch = .x86_64,
        .stack_top = layout.stack_top,
        .runtime_entry = layout.runtime_entry,
        .dtb_address = 0,
        .runtime_abi = .{
            .arg0 = 0,
            .arg1 = 0,
            .arg2 = 0,
            .arg3 = 0,
        },
        .control_state = .{
            .x86_64_cr3 = layout.cr3,
            .aarch64_ttbr0_el1 = 0,
            .riscv64_satp = 0,
        },
        .memory_regions = .{
            .{ .base = layout.reserved_base, .length = layout.reserved_length, .kind = .reserved },
            .{ .base = layout.boot_base, .length = layout.boot_length, .kind = .boot },
            .{ .base = layout.runtime_base, .length = layout.runtime_length, .kind = .runtime },
            .{ .base = 0, .length = 0, .kind = .reserved },
        },
        .memory_region_count = 3,
    };

    try handoff.validate();
    return handoff;
}

pub fn buildHandoff() contract.BootError!contract.BootHandoff {
    const stage = reset.prepareResetStage();
    try reset.validateResetStage(stage);

    return buildHandoffForProfile(.qemu_pc);
}
