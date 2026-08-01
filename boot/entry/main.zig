const std = @import("std");
const builtin = @import("builtin");

const contract = @import("contract.zig");
const loader_contract = @import("../loader/contract.zig");
const cpu_contract = @import("../cpu/contract.zig");
const memory_contract = @import("../memory/contract.zig");
const startup_x86_64 = @import("../startup/x86_64.zig");
const startup_aarch64 = @import("../startup/aarch64.zig");
const startup_riscv64 = @import("../startup/riscv64.zig");

pub const BootError = contract.BootError;
pub const BootArch = contract.BootArch;
pub const BootHandoff = contract.BootHandoff;
pub const RuntimeAbi = contract.RuntimeAbi;
pub const RuntimeAbiRegisterNames = contract.RuntimeAbiRegisterNames;
pub const ControlState = contract.ControlState;
pub const RuntimeHandoffContract = contract.RuntimeHandoffContract;
pub const X86_64Profile = startup_x86_64.X86_64Profile;

pub const X86_64_RESET_VECTOR_SYMBOL = contract.X86_64_RESET_VECTOR_SYMBOL;
pub const X86_64_STARTUP_ENTRY_SYMBOL = contract.X86_64_STARTUP_ENTRY_SYMBOL;
pub const X86_64_RUNTIME_HANDOFF_SYMBOL = contract.X86_64_RUNTIME_HANDOFF_SYMBOL;
pub const X86_64_TEMP_STACK_TOP_SYMBOL = contract.X86_64_TEMP_STACK_TOP_SYMBOL;
pub const X86_64_HANDOFF_PAYLOAD_SYMBOL = contract.X86_64_HANDOFF_PAYLOAD_SYMBOL;
pub const X86_64_BOOT_ENTRY_SYMBOL = contract.X86_64_BOOT_ENTRY_SYMBOL;

pub const runtimeAbiRegisterNamesForArch = contract.runtimeAbiRegisterNamesForArch;
pub const validateRuntimeAbiForArch = contract.validateRuntimeAbiForArch;
pub const controlRegisterNameForArch = contract.controlRegisterNameForArch;
pub const validateControlStateForArch = contract.validateControlStateForArch;
pub const runtimeHandoffContractForArch = contract.runtimeHandoffContractForArch;
pub const validateX86_64AssemblySymbolContract = contract.validateX86_64AssemblySymbolContract;
pub const validateAarch64AssemblySymbolContract = contract.validateAarch64AssemblySymbolContract;
pub const validateRiscv64AssemblySymbolContract = contract.validateRiscv64AssemblySymbolContract;
pub const validateAssemblySymbolContractForArch = contract.validateAssemblySymbolContractForArch;
pub const buildX86_64HandoffForProfile = startup_x86_64.buildHandoffForProfile;

pub const CpuInitContract = cpu_contract.CpuInitContract;
pub const CpuCapabilityReport = cpu_contract.CpuCapabilityReport;
pub const cpuInitContractForArch = cpu_contract.cpuInitContractForArch;
pub const capabilityReportForArch = cpu_contract.capabilityReportForArch;
pub const validateCpuInitContract = cpu_contract.validateCpuInitContract;

pub const PageTableStrategy = memory_contract.PageTableStrategy;
pub const EarlyMemoryLayout = memory_contract.EarlyMemoryLayout;
pub const pageTableStrategyForArch = memory_contract.pageTableStrategyForArch;
pub const earlyMemoryLayoutFromHandoff = memory_contract.earlyMemoryLayoutFromHandoff;
pub const validateEarlyMemoryLayout = memory_contract.validateEarlyMemoryLayout;

pub const ImageHeader = loader_contract.ImageHeader;
pub const LoaderFailureAction = loader_contract.LoaderFailureAction;
pub const IMAGE_MAGIC = loader_contract.IMAGE_MAGIC;
pub const computeImageChecksum = loader_contract.computeImageChecksum;
pub const validateImageHeader = loader_contract.validateImageHeader;
pub const failureActionForError = loader_contract.failureActionForError;

pub fn detectArch() BootError!BootArch {
    return switch (builtin.cpu.arch) {
        .x86_64 => .x86_64,
        .aarch64 => .aarch64,
        .riscv64 => .riscv64,
        else => error.UnsupportedArchitecture,
    };
}

pub fn bootstrap() BootError!BootHandoff {
    // Prompt 02 contract-level flow:
    // detect architecture -> build startup handoff -> validate loader contract.
    const arch = try detectArch();
    const handoff: BootHandoff = switch (arch) {
        .x86_64 => try startup_x86_64.buildHandoff(),
        .aarch64 => try startup_aarch64.buildHandoff(),
        .riscv64 => try startup_riscv64.buildHandoff(),
    };

    try loader_contract.handoffToRuntime(handoff);
    return handoff;
}

pub export fn _start() callconv(.naked) noreturn {
    // Keep boot entry freestanding; no runtime calls in a naked function.
    while (true) {}
}

pub fn panic(_: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    while (true) {}
}
