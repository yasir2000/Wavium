const arch_id = @import("arch_id.zig");
pub const Arch = arch_id.Arch;

pub const RegisterNames = struct {
    stack_pointer: []const u8,
    frame_pointer: []const u8,
    return_address: []const u8,
    program_counter: []const u8,
};

/// Central per-architecture register naming table. Runtime and context-switch
/// code reads register roles from here instead of hardcoding architecture
/// register names inline.
pub fn namesForArch(arch: Arch) RegisterNames {
    return switch (arch) {
        .x86_64 => .{
            .stack_pointer = "rsp",
            .frame_pointer = "rbp",
            .return_address = "return_slot",
            .program_counter = "rip",
        },
        .aarch64 => .{
            .stack_pointer = "sp",
            .frame_pointer = "x29",
            .return_address = "x30",
            .program_counter = "pc",
        },
        .riscv64 => .{
            .stack_pointer = "sp",
            .frame_pointer = "s0",
            .return_address = "ra",
            .program_counter = "pc",
        },
    };
}
