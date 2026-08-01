const contract = @import("../entry/contract.zig");

pub const RESET_VECTOR_ALIGNMENT: u64 = 4096;

pub const ResetStage = struct {
    arch: contract.BootArch,
    vector_address: u64,
    interrupts_masked: bool,
    mmu_enabled: bool,
    caches_enabled: bool,
};

pub fn prepareResetStage() ResetStage {
    return .{
        .arch = .riscv64,
        .vector_address = 0x8000_0000,
        .interrupts_masked = true,
        .mmu_enabled = false,
        .caches_enabled = false,
    };
}

pub fn validateResetStage(stage: ResetStage) contract.BootError!void {
    if (stage.arch != .riscv64) {
        return error.ArchMismatch;
    }
    if ((stage.vector_address % RESET_VECTOR_ALIGNMENT) != 0) {
        return error.InvalidResetVector;
    }
    if (!stage.interrupts_masked or stage.mmu_enabled or stage.caches_enabled) {
        return error.InvalidResetState;
    }
}
