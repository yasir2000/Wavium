const std = @import("std");
const contract = @import("../entry/contract.zig");

pub const IMAGE_MAGIC: u32 = 0x5741_5630; // "WAV0"

pub const ImageHeader = struct {
    magic: u32,
    arch: contract.BootArch,
    length: u64,
    checksum: u32,
};

pub const LoaderFailureAction = enum {
    halt,
};

pub fn validateHandoff(handoff: contract.BootHandoff) contract.BootError!void {
    try handoff.validate();
}

pub fn handoffToRuntime(handoff: contract.BootHandoff) contract.BootError!void {
    // Prompt 02 contract: validate shape before a later milestone introduces
    // an actual runtime jump and register/memory handoff.
    try validateHandoff(handoff);
}

pub fn computeImageChecksum(data: []const u8) u32 {
    var sum: u32 = 0;
    for (data) |byte| {
        sum = sum +% byte;
        sum = std.math.rotl(u32, sum, 1);
    }
    return sum;
}

pub fn validateImageHeader(header: ImageHeader, expected_arch: contract.BootArch, data: []const u8) contract.BootError!void {
    if (header.magic != IMAGE_MAGIC) {
        return error.InvalidImageHeader;
    }
    if (header.arch != expected_arch) {
        return error.ArchMismatch;
    }
    if (header.length != data.len) {
        return error.InvalidImageHeader;
    }
    if (header.checksum != computeImageChecksum(data)) {
        return error.InvalidImageHeader;
    }
}

/// Prompt 02 milestone policy: any loader-stage failure halts rather than
/// attempting rollback to a previous stage. Rollback/retry behavior is
/// deferred to a later milestone.
pub fn failureActionForError(_: contract.BootError) LoaderFailureAction {
    return .halt;
}
