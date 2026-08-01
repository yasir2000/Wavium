const std = @import("std");

pub const BootArch = enum {
    x86_64,
    aarch64,
    riscv64,
};

pub const MemoryRegionKind = enum {
    reserved,
    boot,
    runtime,
};

pub const MemoryRegion = struct {
    base: u64,
    length: u64,
    kind: MemoryRegionKind,
};

pub const BootError = error{
    UnsupportedArchitecture,
    ArchMismatch,
    InvalidResetVector,
    InvalidResetState,
    InvalidMemoryMap,
    InvalidStackPointer,
    InvalidRuntimeEntry,
    InvalidRuntimeAbi,
    InvalidControlState,
    InvalidAssemblyContract,
    InvalidImageHeader,
};

pub const STACK_ALIGNMENT: u64 = 16;
pub const ENTRY_ALIGNMENT: u64 = 4;

pub const X86_64_RESET_VECTOR_SYMBOL = "wavium_x86_64_reset_vector";
pub const X86_64_STARTUP_ENTRY_SYMBOL = "wavium_x86_64_startup_entry";
pub const X86_64_RUNTIME_HANDOFF_SYMBOL = "wavium_x86_64_runtime_handoff";
pub const X86_64_TEMP_STACK_TOP_SYMBOL = "wavium_x86_64_temp_stack_top";
pub const X86_64_HANDOFF_PAYLOAD_SYMBOL = "wavium_x86_64_handoff_payload";
pub const X86_64_BOOT_ENTRY_SYMBOL = "_start";

pub const AARCH64_RESET_VECTOR_SYMBOL = "wavium_aarch64_reset_vector";
pub const AARCH64_STARTUP_ENTRY_SYMBOL = "wavium_aarch64_startup_entry";
pub const AARCH64_RUNTIME_HANDOFF_SYMBOL = "wavium_aarch64_runtime_handoff";
pub const AARCH64_TEMP_STACK_TOP_SYMBOL = "wavium_aarch64_temp_stack_top";
pub const AARCH64_HANDOFF_PAYLOAD_SYMBOL = "wavium_aarch64_handoff_payload";
pub const AARCH64_BOOT_ENTRY_SYMBOL = "_start";

pub const RISCV64_RESET_VECTOR_SYMBOL = "wavium_riscv64_reset_vector";
pub const RISCV64_STARTUP_ENTRY_SYMBOL = "wavium_riscv64_startup_entry";
pub const RISCV64_RUNTIME_HANDOFF_SYMBOL = "wavium_riscv64_runtime_handoff";
pub const RISCV64_TEMP_STACK_TOP_SYMBOL = "wavium_riscv64_temp_stack_top";
pub const RISCV64_HANDOFF_PAYLOAD_SYMBOL = "wavium_riscv64_handoff_payload";
pub const RISCV64_BOOT_ENTRY_SYMBOL = "_start";

const x86_reset_asm = @embedFile("../reset/x86_64_reset.S");
const x86_startup_asm = @embedFile("../startup/x86_64_startup.S");
const aarch64_reset_asm = @embedFile("../reset/aarch64_reset.S");
const aarch64_startup_asm = @embedFile("../startup/aarch64_startup.S");
const riscv64_reset_asm = @embedFile("../reset/riscv64_reset.S");
const riscv64_startup_asm = @embedFile("../startup/riscv64_startup.S");

pub const RuntimeAbi = struct {
    arg0: u64,
    arg1: u64,
    arg2: u64,
    arg3: u64,
};

pub const RuntimeAbiRegisterNames = struct {
    arg0: []const u8,
    arg1: []const u8,
    arg2: []const u8,
    arg3: []const u8,
};

pub const ControlState = struct {
    x86_64_cr3: u64,
    aarch64_ttbr0_el1: u64,
    riscv64_satp: u64,
};

pub const RuntimeHandoffContract = struct {
    entry_symbol: []const u8,
    stack_pointer_register: []const u8,
    arg_register_0: []const u8,
    interrupts_must_be_masked: bool,
};

pub fn runtimeAbiRegisterNamesForArch(arch: BootArch) RuntimeAbiRegisterNames {
    return switch (arch) {
        .x86_64 => .{
            .arg0 = "rdi",
            .arg1 = "rsi",
            .arg2 = "rdx",
            .arg3 = "rcx",
        },
        .aarch64 => .{
            .arg0 = "x0",
            .arg1 = "x1",
            .arg2 = "x2",
            .arg3 = "x3",
        },
        .riscv64 => .{
            .arg0 = "a0",
            .arg1 = "a1",
            .arg2 = "a2",
            .arg3 = "a3",
        },
    };
}

pub fn validateRuntimeAbiForArch(arch: BootArch, runtime_abi: RuntimeAbi, dtb_address: u64) BootError!void {
    switch (arch) {
        .x86_64 => {
            if (dtb_address != 0 or runtime_abi.arg0 != 0) {
                return error.InvalidRuntimeAbi;
            }
        },
        .aarch64, .riscv64 => {
            if (dtb_address == 0) {
                return error.InvalidRuntimeAbi;
            }
            if (runtime_abi.arg0 != dtb_address) {
                return error.InvalidRuntimeAbi;
            }
        },
    }
}

pub fn controlRegisterNameForArch(arch: BootArch) []const u8 {
    return switch (arch) {
        .x86_64 => "cr3",
        .aarch64 => "ttbr0_el1",
        .riscv64 => "satp",
    };
}

pub fn runtimeHandoffContractForArch(arch: BootArch) RuntimeHandoffContract {
    return switch (arch) {
        .x86_64 => .{
            .entry_symbol = X86_64_RUNTIME_HANDOFF_SYMBOL,
            .stack_pointer_register = "rsp",
            .arg_register_0 = "rdi",
            .interrupts_must_be_masked = true,
        },
        .aarch64 => .{
            .entry_symbol = "wavium_aarch64_runtime_handoff",
            .stack_pointer_register = "sp",
            .arg_register_0 = "x0",
            .interrupts_must_be_masked = true,
        },
        .riscv64 => .{
            .entry_symbol = "wavium_riscv64_runtime_handoff",
            .stack_pointer_register = "sp",
            .arg_register_0 = "a0",
            .interrupts_must_be_masked = true,
        },
    };
}

pub fn validateX86_64AssemblySymbolContract() BootError!void {
    if (std.mem.indexOf(u8, x86_reset_asm, X86_64_BOOT_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, x86_reset_asm, X86_64_RESET_VECTOR_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, x86_reset_asm, X86_64_STARTUP_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, x86_startup_asm, X86_64_STARTUP_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, x86_startup_asm, X86_64_RUNTIME_HANDOFF_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, x86_startup_asm, X86_64_TEMP_STACK_TOP_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, x86_startup_asm, X86_64_HANDOFF_PAYLOAD_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
}

pub fn validateAarch64AssemblySymbolContract() BootError!void {
    if (std.mem.indexOf(u8, aarch64_reset_asm, AARCH64_BOOT_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, aarch64_reset_asm, AARCH64_RESET_VECTOR_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, aarch64_reset_asm, AARCH64_STARTUP_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, aarch64_startup_asm, AARCH64_STARTUP_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, aarch64_startup_asm, AARCH64_RUNTIME_HANDOFF_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, aarch64_startup_asm, AARCH64_TEMP_STACK_TOP_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, aarch64_startup_asm, AARCH64_HANDOFF_PAYLOAD_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
}

pub fn validateRiscv64AssemblySymbolContract() BootError!void {
    if (std.mem.indexOf(u8, riscv64_reset_asm, RISCV64_BOOT_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, riscv64_reset_asm, RISCV64_RESET_VECTOR_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, riscv64_reset_asm, RISCV64_STARTUP_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, riscv64_startup_asm, RISCV64_STARTUP_ENTRY_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, riscv64_startup_asm, RISCV64_RUNTIME_HANDOFF_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, riscv64_startup_asm, RISCV64_TEMP_STACK_TOP_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
    if (std.mem.indexOf(u8, riscv64_startup_asm, RISCV64_HANDOFF_PAYLOAD_SYMBOL) == null) {
        return error.InvalidAssemblyContract;
    }
}

pub fn validateAssemblySymbolContractForArch(arch: BootArch) BootError!void {
    return switch (arch) {
        .x86_64 => validateX86_64AssemblySymbolContract(),
        .aarch64 => validateAarch64AssemblySymbolContract(),
        .riscv64 => validateRiscv64AssemblySymbolContract(),
    };
}

pub fn validateControlStateForArch(arch: BootArch, control_state: ControlState) BootError!void {
    switch (arch) {
        .x86_64 => {
            if (control_state.x86_64_cr3 == 0) {
                return error.InvalidControlState;
            }
            if (control_state.aarch64_ttbr0_el1 != 0 or control_state.riscv64_satp != 0) {
                return error.InvalidControlState;
            }
        },
        .aarch64 => {
            if (control_state.aarch64_ttbr0_el1 == 0) {
                return error.InvalidControlState;
            }
            if (control_state.x86_64_cr3 != 0 or control_state.riscv64_satp != 0) {
                return error.InvalidControlState;
            }
        },
        .riscv64 => {
            if (control_state.riscv64_satp == 0) {
                return error.InvalidControlState;
            }
            if (control_state.x86_64_cr3 != 0 or control_state.aarch64_ttbr0_el1 != 0) {
                return error.InvalidControlState;
            }
        },
    }
}

pub const BootHandoff = struct {
    arch: BootArch,
    stack_top: u64,
    runtime_entry: u64,
    dtb_address: u64,
    runtime_abi: RuntimeAbi,
    control_state: ControlState,
    memory_regions: [4]MemoryRegion,
    memory_region_count: u8,

    pub fn validate(self: BootHandoff) BootError!void {
        if (self.stack_top == 0 or (self.stack_top % STACK_ALIGNMENT) != 0) {
            return error.InvalidStackPointer;
        }

        if (self.runtime_entry == 0 or (self.runtime_entry % ENTRY_ALIGNMENT) != 0) {
            return error.InvalidRuntimeEntry;
        }

        if (self.memory_region_count == 0 or self.memory_region_count > self.memory_regions.len) {
            return error.InvalidMemoryMap;
        }

        var idx: usize = 0;
        while (idx < self.memory_region_count) : (idx += 1) {
            if (self.memory_regions[idx].length == 0) {
                return error.InvalidMemoryMap;
            }
        }

        try validateRuntimeAbiForArch(self.arch, self.runtime_abi, self.dtb_address);
        try validateControlStateForArch(self.arch, self.control_state);
    }

    pub fn runtimeAbiRegisterNames(self: BootHandoff) RuntimeAbiRegisterNames {
        return runtimeAbiRegisterNamesForArch(self.arch);
    }
};
