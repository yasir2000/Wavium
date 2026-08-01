const std = @import("std");
const arch_mod = @import("arch.zig");
const vector_mod = @import("vector.zig");
const transport_mod = @import("transport.zig");

pub const BenchmarkResult = struct {
    send_ns: u64,
    broadcast_ns: u64,
    multicast_ns: u64,
    iterations: usize,
};

fn noopSend(_: arch_mod.CoreId, _: u8) bool {
    return true;
}

/// Times `iterations` rounds of `send`/`broadcast`/`multicast` against a
/// no-op backend, so the numbers reflect this module's own dispatch
/// overhead (loop/branch cost) independent of any real interrupt
/// controller latency.
pub fn runSuite(comptime core_count: arch_mod.CoreId, iterations: usize) BenchmarkResult {
    const transport = transport_mod.Transport{
        .backend = .{ .arch = .x86_apic, .send_fn = noopSend },
        .local_core = 0,
    };

    var timer = std.time.Timer.start() catch unreachable;
    var i: usize = 0;
    while (i < iterations) : (i += 1) {
        _ = transport.send(1, .wake) catch {};
    }
    const send_ns = timer.lap();

    i = 0;
    while (i < iterations) : (i += 1) {
        _ = transport.broadcast(core_count, .reschedule) catch {};
    }
    const broadcast_ns = timer.lap();

    i = 0;
    while (i < iterations) : (i += 1) {
        _ = transport.multicast(0xF, .mailbox_notify) catch {};
    }
    const multicast_ns = timer.lap();

    return .{
        .send_ns = send_ns,
        .broadcast_ns = broadcast_ns,
        .multicast_ns = multicast_ns,
        .iterations = iterations,
    };
}

test "runSuite executes every operation and reports the requested iteration count" {
    const result = runSuite(4, 500);
    try std.testing.expectEqual(@as(usize, 500), result.iterations);
    // Wall-clock timings are environment-dependent; only assert the
    // benchmark actually ran end to end, not any specific timing outcome.
}
