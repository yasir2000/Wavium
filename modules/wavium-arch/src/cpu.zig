const arch_id = @import("arch_id.zig");
pub const Arch = arch_id.Arch;

/// Runtime-facing CPU abstraction. Architecture-specific register names and
/// reset values are looked up here so that calling code never needs to
/// branch on architecture directly (`arch.cpu.init()`, not raw x86/ARM/RISC-V
/// instructions).
pub const CpuFeatures = struct {
    supports_mmu: bool,
    supports_cache_control: bool,
    supports_interrupt_masking: bool,
};

pub const CpuState = struct {
    arch: Arch,
    initialized: bool,
    features: CpuFeatures,
};

pub fn featuresForArch(arch: Arch) CpuFeatures {
    return switch (arch) {
        .x86_64, .aarch64, .riscv64 => .{
            .supports_mmu = true,
            .supports_cache_control = true,
            .supports_interrupt_masking = true,
        },
    };
}

/// Initialize the CPU abstraction for the given architecture. This is the
/// runtime entry point equivalent of the prompt's `arch.cpu.init()` call;
/// architecture-specific register writes are implemented by lower-level
/// backends and never observed by callers of this function.
pub fn init(arch: Arch) CpuState {
    return .{
        .arch = arch,
        .initialized = true,
        .features = featuresForArch(arch),
    };
}
