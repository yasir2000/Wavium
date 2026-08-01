const std = @import("std");
const arch_mod = @import("arch.zig");
const vector_mod = @import("vector.zig");

pub const TransportError = arch_mod.SendError || error{NoTargets};

/// Core-facing IPC/IPI API: `send` (one target), `broadcast` (every other
/// core), and `multicast` (an arbitrary subset via bitmask). All three sit
/// on top of the arch-abstracted `ArchBackend.send`.
pub const Transport = struct {
    backend: arch_mod.ArchBackend,
    local_core: arch_mod.CoreId,

    pub fn send(self: Transport, target_core: arch_mod.CoreId, vector: vector_mod.IpiVector) TransportError!void {
        try self.backend.send(target_core, @intFromEnum(vector));
    }

    /// Sends `vector` to every core in `0..core_count` other than the
    /// local core.
    pub fn broadcast(self: Transport, core_count: arch_mod.CoreId, vector: vector_mod.IpiVector) TransportError!void {
        var sent: usize = 0;
        var core: arch_mod.CoreId = 0;
        while (core < core_count) : (core += 1) {
            if (core == self.local_core) continue;
            try self.send(core, vector);
            sent += 1;
        }
        if (sent == 0) return error.NoTargets;
    }

    /// Sends `vector` to every core whose bit is set in `mask` (bit N =
    /// core N), skipping the local core.
    pub fn multicast(self: Transport, mask: u64, vector: vector_mod.IpiVector) TransportError!void {
        var sent: usize = 0;
        var bit: u6 = 0;
        while (true) {
            const core: arch_mod.CoreId = bit;
            if ((mask & (@as(u64, 1) << bit)) != 0 and core != self.local_core) {
                try self.send(core, vector);
                sent += 1;
            }
            if (bit == 63) break;
            bit += 1;
        }
        if (sent == 0) return error.NoTargets;
    }
};

var call_log: [8]struct { core: arch_mod.CoreId, vector: u8 } = undefined;
var call_count: usize = 0;

fn recordingSend(target_core: arch_mod.CoreId, vector: u8) bool {
    if (call_count < call_log.len) {
        call_log[call_count] = .{ .core = target_core, .vector = vector };
    }
    call_count += 1;
    return true;
}

test "send dispatches a single targeted IPI" {
    call_count = 0;
    const transport = Transport{
        .backend = .{ .arch = .x86_apic, .send_fn = recordingSend },
        .local_core = 0,
    };
    try transport.send(3, .wake);
    try std.testing.expectEqual(@as(usize, 1), call_count);
    try std.testing.expectEqual(@as(arch_mod.CoreId, 3), call_log[0].core);
}

test "broadcast reaches every core except the sender" {
    call_count = 0;
    const transport = Transport{
        .backend = .{ .arch = .arm_gic, .send_fn = recordingSend },
        .local_core = 1,
    };
    try transport.broadcast(4, .reschedule);
    try std.testing.expectEqual(@as(usize, 3), call_count);
    for (call_log[0..call_count]) |entry| {
        try std.testing.expect(entry.core != 1);
    }
}

test "multicast targets only the cores set in the mask, excluding self" {
    call_count = 0;
    const transport = Transport{
        .backend = .{ .arch = .riscv_clint_sbi, .send_fn = recordingSend },
        .local_core = 2,
    };
    // cores 2, 4, 5 requested; core 2 is local and must be skipped.
    const mask: u64 = (1 << 2) | (1 << 4) | (1 << 5);
    try transport.multicast(mask, .mailbox_notify);
    try std.testing.expectEqual(@as(usize, 2), call_count);
}

test "broadcast and multicast report NoTargets when nothing else can be reached" {
    call_count = 0;
    const transport = Transport{
        .backend = .{ .arch = .x86_apic, .send_fn = recordingSend },
        .local_core = 0,
    };
    try std.testing.expectError(error.NoTargets, transport.broadcast(1, .wake));
    try std.testing.expectError(error.NoTargets, transport.multicast(1 << 0, .wake));
}
