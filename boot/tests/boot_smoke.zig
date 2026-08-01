const std = @import("std");
const boot = @import("wavium-boot-prompt02");

test "detectArch maps supported host architectures" {
    const arch = @import("builtin").cpu.arch;
    if (arch == .x86_64 or arch == .aarch64 or arch == .riscv64) {
        const detected = try boot.detectArch();
        const expected: boot.BootArch = switch (arch) {
            .x86_64 => .x86_64,
            .aarch64 => .aarch64,
            .riscv64 => .riscv64,
            else => unreachable,
        };
        try std.testing.expectEqual(expected, detected);
    } else {
        try std.testing.expectError(boot.BootError.UnsupportedArchitecture, boot.detectArch());
    }
}

test "bootstrap returns validated handoff on supported architectures" {
    const arch = @import("builtin").cpu.arch;
    if (!(arch == .x86_64 or arch == .aarch64 or arch == .riscv64)) {
        return;
    }

    const handoff = try boot.bootstrap();
    try std.testing.expect(handoff.stack_top != 0);
    try std.testing.expect(handoff.runtime_entry != 0);
    try std.testing.expect(handoff.memory_region_count > 0);
    try std.testing.expect(handoff.memory_region_count <= handoff.memory_regions.len);
}

test "handoff validation rejects zero-length region" {
    var handoff = boot.BootHandoff{
        .arch = .x86_64,
        .stack_top = 0x1000,
        .runtime_entry = 0x2000,
        .dtb_address = 0,
        .runtime_abi = .{ .arg0 = 0, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
        .control_state = .{
            .x86_64_cr3 = 0x3000,
            .aarch64_ttbr0_el1 = 0,
            .riscv64_satp = 0,
        },
        .memory_regions = .{
            .{ .base = 0, .length = 0, .kind = .boot },
            .{ .base = 0, .length = 0, .kind = .reserved },
            .{ .base = 0, .length = 0, .kind = .reserved },
            .{ .base = 0, .length = 0, .kind = .reserved },
        },
        .memory_region_count = 1,
    };
    try std.testing.expectError(boot.BootError.InvalidMemoryMap, handoff.validate());
}

test "handoff validation rejects misaligned stack" {
    const handoff = boot.BootHandoff{
        .arch = .x86_64,
        .stack_top = 0x1003,
        .runtime_entry = 0x2000,
        .dtb_address = 0,
        .runtime_abi = .{ .arg0 = 0, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
        .control_state = .{
            .x86_64_cr3 = 0x3000,
            .aarch64_ttbr0_el1 = 0,
            .riscv64_satp = 0,
        },
        .memory_regions = .{
            .{ .base = 0, .length = 0x1000, .kind = .boot },
            .{ .base = 0x1000, .length = 0x2000, .kind = .runtime },
            .{ .base = 0, .length = 0, .kind = .reserved },
            .{ .base = 0, .length = 0, .kind = .reserved },
        },
        .memory_region_count = 2,
    };
    try std.testing.expectError(boot.BootError.InvalidStackPointer, handoff.validate());
}

test "handoff validation rejects zero runtime entry" {
    const handoff = boot.BootHandoff{
        .arch = .x86_64,
        .stack_top = 0x1000,
        .runtime_entry = 0,
        .dtb_address = 0,
        .runtime_abi = .{ .arg0 = 0, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
        .control_state = .{
            .x86_64_cr3 = 0x3000,
            .aarch64_ttbr0_el1 = 0,
            .riscv64_satp = 0,
        },
        .memory_regions = .{
            .{ .base = 0, .length = 0x1000, .kind = .boot },
            .{ .base = 0x1000, .length = 0x2000, .kind = .runtime },
            .{ .base = 0, .length = 0, .kind = .reserved },
            .{ .base = 0, .length = 0, .kind = .reserved },
        },
        .memory_region_count = 2,
    };
    try std.testing.expectError(boot.BootError.InvalidRuntimeEntry, handoff.validate());
}

test "control register names are architecture-specific" {
    try std.testing.expectEqualStrings("cr3", boot.controlRegisterNameForArch(.x86_64));
    try std.testing.expectEqualStrings("ttbr0_el1", boot.controlRegisterNameForArch(.aarch64));
    try std.testing.expectEqualStrings("satp", boot.controlRegisterNameForArch(.riscv64));
}

test "control state policy validates architecture-specific ownership" {
    try boot.validateControlStateForArch(
        .x86_64,
        .{ .x86_64_cr3 = 0x3000, .aarch64_ttbr0_el1 = 0, .riscv64_satp = 0 },
    );
    try std.testing.expectError(
        boot.BootError.InvalidControlState,
        boot.validateControlStateForArch(
            .x86_64,
            .{ .x86_64_cr3 = 0, .aarch64_ttbr0_el1 = 0, .riscv64_satp = 0 },
        ),
    );

    try boot.validateControlStateForArch(
        .aarch64,
        .{ .x86_64_cr3 = 0, .aarch64_ttbr0_el1 = 0x1000, .riscv64_satp = 0 },
    );
    try std.testing.expectError(
        boot.BootError.InvalidControlState,
        boot.validateControlStateForArch(
            .aarch64,
            .{ .x86_64_cr3 = 0x2000, .aarch64_ttbr0_el1 = 0x1000, .riscv64_satp = 0 },
        ),
    );

    try boot.validateControlStateForArch(
        .riscv64,
        .{ .x86_64_cr3 = 0, .aarch64_ttbr0_el1 = 0, .riscv64_satp = 0x8000_0000_0000_0001 },
    );
    try std.testing.expectError(
        boot.BootError.InvalidControlState,
        boot.validateControlStateForArch(
            .riscv64,
            .{ .x86_64_cr3 = 0, .aarch64_ttbr0_el1 = 0x1000, .riscv64_satp = 0x8000_0000_0000_0001 },
        ),
    );
}

test "runtime ABI register names are architecture-specific" {
    const x86_regs = boot.runtimeAbiRegisterNamesForArch(.x86_64);
    try std.testing.expectEqualStrings("rdi", x86_regs.arg0);
    try std.testing.expectEqualStrings("rsi", x86_regs.arg1);
    try std.testing.expectEqualStrings("rdx", x86_regs.arg2);
    try std.testing.expectEqualStrings("rcx", x86_regs.arg3);

    const arm_regs = boot.runtimeAbiRegisterNamesForArch(.aarch64);
    try std.testing.expectEqualStrings("x0", arm_regs.arg0);
    try std.testing.expectEqualStrings("x1", arm_regs.arg1);
    try std.testing.expectEqualStrings("x2", arm_regs.arg2);
    try std.testing.expectEqualStrings("x3", arm_regs.arg3);

    const riscv_regs = boot.runtimeAbiRegisterNamesForArch(.riscv64);
    try std.testing.expectEqualStrings("a0", riscv_regs.arg0);
    try std.testing.expectEqualStrings("a1", riscv_regs.arg1);
    try std.testing.expectEqualStrings("a2", riscv_regs.arg2);
    try std.testing.expectEqualStrings("a3", riscv_regs.arg3);
}

test "runtime ABI policy validates DTB rules per architecture" {
    try boot.validateRuntimeAbiForArch(
        .x86_64,
        .{ .arg0 = 0, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
        0,
    );
    try std.testing.expectError(
        boot.BootError.InvalidRuntimeAbi,
        boot.validateRuntimeAbiForArch(
            .x86_64,
            .{ .arg0 = 1, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
            0,
        ),
    );

    try boot.validateRuntimeAbiForArch(
        .aarch64,
        .{ .arg0 = 0x4000, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
        0x4000,
    );
    try std.testing.expectError(
        boot.BootError.InvalidRuntimeAbi,
        boot.validateRuntimeAbiForArch(
            .aarch64,
            .{ .arg0 = 0, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
            0x4000,
        ),
    );

    try boot.validateRuntimeAbiForArch(
        .riscv64,
        .{ .arg0 = 0x8100_0000, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
        0x8100_0000,
    );
    try std.testing.expectError(
        boot.BootError.InvalidRuntimeAbi,
        boot.validateRuntimeAbiForArch(
            .riscv64,
            .{ .arg0 = 0x8100_0001, .arg1 = 0, .arg2 = 0, .arg3 = 0 },
            0x8100_0000,
        ),
    );
}

test "x86_64 profile handoffs are valid and distinct" {
    const qemu = try boot.buildX86_64HandoffForProfile(.qemu_pc);
    const uefi = try boot.buildX86_64HandoffForProfile(.uefi_vm);

    try std.testing.expectEqual(@as(boot.BootArch, .x86_64), qemu.arch);
    try std.testing.expectEqual(@as(boot.BootArch, .x86_64), uefi.arch);

    try std.testing.expect(qemu.stack_top != uefi.stack_top);
    try std.testing.expect(qemu.runtime_entry != uefi.runtime_entry);
    try std.testing.expect(qemu.control_state.x86_64_cr3 != uefi.control_state.x86_64_cr3);

    try std.testing.expectEqual(@as(u64, 0), qemu.control_state.aarch64_ttbr0_el1);
    try std.testing.expectEqual(@as(u64, 0), qemu.control_state.riscv64_satp);
    try std.testing.expectEqual(@as(u64, 0), uefi.control_state.aarch64_ttbr0_el1);
    try std.testing.expectEqual(@as(u64, 0), uefi.control_state.riscv64_satp);
}

test "x86_64 assembly skeleton exposes required symbol labels" {
    try boot.validateX86_64AssemblySymbolContract();
}

test "aarch64 assembly skeleton exposes required symbol labels" {
    try boot.validateAarch64AssemblySymbolContract();
}

test "riscv64 assembly skeleton exposes required symbol labels" {
    try boot.validateRiscv64AssemblySymbolContract();
}

test "per-arch assembly symbol contract dispatcher matches direct validators" {
    try boot.validateAssemblySymbolContractForArch(.x86_64);
    try boot.validateAssemblySymbolContractForArch(.aarch64);
    try boot.validateAssemblySymbolContractForArch(.riscv64);
}

test "cpu init contract is architecture-specific and valid" {
    const x86 = boot.cpuInitContractForArch(.x86_64);
    try std.testing.expectEqualStrings("cr0", x86.control_register_name);
    try std.testing.expectEqualStrings("rsp", x86.stack_pointer_register);
    try boot.validateCpuInitContract(x86);

    const arm = boot.cpuInitContractForArch(.aarch64);
    try std.testing.expectEqualStrings("sctlr_el1", arm.control_register_name);
    try boot.validateCpuInitContract(arm);

    const riscv = boot.cpuInitContractForArch(.riscv64);
    try std.testing.expectEqualStrings("mstatus", riscv.control_register_name);
    try boot.validateCpuInitContract(riscv);
}

test "cpu capability report reflects arch" {
    const report = boot.capabilityReportForArch(.aarch64);
    try std.testing.expectEqual(@as(boot.BootArch, .aarch64), report.arch);
    try std.testing.expect(report.supports_mmu);
}

test "early memory layout derived from handoff requires a runtime region" {
    const handoff = try boot.buildX86_64HandoffForProfile(.qemu_pc);
    const layout = boot.earlyMemoryLayoutFromHandoff(handoff);
    try boot.validateEarlyMemoryLayout(layout);
    try std.testing.expectEqual(boot.PageTableStrategy.identity_map_low, layout.page_table_strategy);
}

test "early memory layout rejects missing runtime region" {
    const layout = boot.EarlyMemoryLayout{
        .arch = .riscv64,
        .page_table_strategy = boot.pageTableStrategyForArch(.riscv64),
        .regions = .{
            .{ .base = 0, .length = 0x1000, .kind = .reserved },
            .{ .base = 0x1000, .length = 0x1000, .kind = .boot },
            .{ .base = 0, .length = 0, .kind = .reserved },
            .{ .base = 0, .length = 0, .kind = .reserved },
        },
        .region_count = 2,
    };
    try std.testing.expectError(boot.BootError.InvalidMemoryMap, boot.validateEarlyMemoryLayout(layout));
    try std.testing.expectEqual(boot.PageTableStrategy.identity_map_flat, boot.pageTableStrategyForArch(.riscv64));
}

test "loader image header validation accepts matching checksum and rejects tampering" {
    const data = "WAVIUM_BOOT_TEST_IMAGE_V0\n";
    const checksum = boot.computeImageChecksum(data);
    const header = boot.ImageHeader{
        .magic = boot.IMAGE_MAGIC,
        .arch = .x86_64,
        .length = data.len,
        .checksum = checksum,
    };
    try boot.validateImageHeader(header, .x86_64, data);

    const tampered_header = boot.ImageHeader{
        .magic = boot.IMAGE_MAGIC,
        .arch = .x86_64,
        .length = data.len,
        .checksum = checksum +% 1,
    };
    try std.testing.expectError(boot.BootError.InvalidImageHeader, boot.validateImageHeader(tampered_header, .x86_64, data));

    const wrong_magic_header = boot.ImageHeader{
        .magic = 0,
        .arch = .x86_64,
        .length = data.len,
        .checksum = checksum,
    };
    try std.testing.expectError(boot.BootError.InvalidImageHeader, boot.validateImageHeader(wrong_magic_header, .x86_64, data));

    try std.testing.expectError(boot.BootError.ArchMismatch, boot.validateImageHeader(header, .aarch64, data));
}

test "loader failure action policy halts for Prompt 02 milestone" {
    try std.testing.expectEqual(boot.LoaderFailureAction.halt, boot.failureActionForError(boot.BootError.InvalidImageHeader));
    try std.testing.expectEqual(boot.LoaderFailureAction.halt, boot.failureActionForError(boot.BootError.InvalidMemoryMap));
}

test "runtime handoff contract helper publishes expected x86_64 semantics" {
    const contract = boot.runtimeHandoffContractForArch(.x86_64);
    try std.testing.expectEqualStrings(boot.X86_64_RUNTIME_HANDOFF_SYMBOL, contract.entry_symbol);
    try std.testing.expectEqualStrings("rsp", contract.stack_pointer_register);
    try std.testing.expectEqualStrings("rdi", contract.arg_register_0);
    try std.testing.expect(contract.interrupts_must_be_masked);
    try std.testing.expectEqualStrings("_start", boot.X86_64_BOOT_ENTRY_SYMBOL);
    try std.testing.expectEqualStrings("wavium_x86_64_handoff_payload", boot.X86_64_HANDOFF_PAYLOAD_SYMBOL);
}
