pub const Arch = enum {
    x86_64,
    aarch64,
    riscv64,
};

pub const ArchError = error{
    UnsupportedArchitecture,
};

pub fn current() ArchError!Arch {
    return switch (@import("builtin").cpu.arch) {
        .x86_64 => .x86_64,
        .aarch64 => .aarch64,
        .riscv64 => .riscv64,
        else => error.UnsupportedArchitecture,
    };
}
