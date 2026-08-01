const arch_id = @import("arch_id.zig");
pub const Arch = arch_id.Arch;

pub const TimerError = error{
    InvalidDuration,
};

pub const Duration = struct {
    nanos: u64,
};

/// Nominal timer tick rate per architecture. Real backends will source this
/// from hardware (TSC/APIC timer, generic timer, CLINT/mtime) rather than a
/// fixed constant; this contract exists so runtime code can call
/// `arch.timers.sleep()` without architecture-specific branching.
pub fn nominalTicksPerSecond(arch: Arch) u64 {
    return switch (arch) {
        .x86_64 => 1_000_000_000,
        .aarch64 => 1_000_000_000,
        .riscv64 => 10_000_000,
    };
}

pub fn validateDuration(duration: Duration) TimerError!void {
    if (duration.nanos == 0) {
        return error.InvalidDuration;
    }
}

/// Contract-level sleep: validates the requested duration. Actual busy-wait
/// or timer-interrupt-driven sleep is implemented by architecture backends
/// in a later milestone.
pub fn sleep(duration: Duration) TimerError!void {
    try validateDuration(duration);
}
