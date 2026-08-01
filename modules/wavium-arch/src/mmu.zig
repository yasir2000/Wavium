const arch_id = @import("arch_id.zig");
pub const Arch = arch_id.Arch;

pub const MmuError = error{
    InvalidAlignment,
    InvalidLength,
};

pub const PageFlags = packed struct {
    readable: bool = true,
    writable: bool = false,
    executable: bool = false,
    _padding: u5 = 0,
};

pub const MapRequest = struct {
    virtual_addr: u64,
    physical_addr: u64,
    length: u64,
    flags: PageFlags,
};

pub const PAGE_SIZE: u64 = 4096;

/// Validates a mapping request shape. Runtime code calls `arch.mmu.map()`
/// without knowing whether page tables are built via x86_64 4-level paging,
/// aarch64 translation tables, or riscv64 Sv39/Sv48; that per-architecture
/// table format is owned by a lower-level backend.
pub fn validateMapRequest(request: MapRequest) MmuError!void {
    if (request.length == 0) {
        return error.InvalidLength;
    }
    if ((request.virtual_addr % PAGE_SIZE) != 0 or (request.physical_addr % PAGE_SIZE) != 0) {
        return error.InvalidAlignment;
    }
    if ((request.length % PAGE_SIZE) != 0) {
        return error.InvalidLength;
    }
}

pub fn map(request: MapRequest) MmuError!void {
    try validateMapRequest(request);
}
