const arch_id = @import("arch_id.zig");
pub const Arch = arch_id.Arch;

pub const ContextError = error{
    InvalidStackPointer,
    InvalidProgramCounter,
};

/// Minimal saved-register context needed to resume execution of a stopped
/// task. Real backends extend this per architecture (callee-saved GPRs,
/// vector/FP state) but every backend must be able to populate these fields.
pub const CpuContext = struct {
    arch: Arch,
    stack_pointer: u64,
    program_counter: u64,
};

pub fn validateContext(context: CpuContext) ContextError!void {
    if (context.stack_pointer == 0) {
        return error.InvalidStackPointer;
    }
    if (context.program_counter == 0) {
        return error.InvalidProgramCounter;
    }
}

/// Contract-level context switch: validates both contexts before a later
/// milestone performs the actual register save/restore trampoline per
/// architecture.
pub fn switchContext(from: *CpuContext, to: CpuContext) ContextError!void {
    try validateContext(from.*);
    try validateContext(to);
    from.* = to;
}
