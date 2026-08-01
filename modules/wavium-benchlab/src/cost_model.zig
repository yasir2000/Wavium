//! Deterministic synthetic cost model: since this freestanding
//! runtime's pinned Zig toolchain has no `std.time.Timer` (confirmed
//! gone from `std.time` - see repo notes), "measuring" a benchmark
//! means computing a reproducible cost as a function of
//! (BenchmarkKind, core_count) rather than sampling a wall clock -
//! consistent with every prior benchmark.zig in this repo
//! (Prompts 18/20/23/25/27), which assert on deterministic counts
//! rather than timing.

const metrics = @import("metrics.zig");
const scale = @import("scale.zig");

pub const ScalingProfile = enum {
    /// Per-op latency is independent of core_count (e.g. per-core
    /// local operations with no cross-core contention).
    flat,
    /// Total operations scale up with core_count (more cores doing
    /// independent work in parallel); per-op latency stays flat.
    improves_with_cores,
    /// Per-op latency grows slowly (log2) with core_count due to
    /// cross-core coordination/contention.
    degrades_with_cores,
};

pub fn profileFor(kind: metrics.BenchmarkKind) ScalingProfile {
    return switch (kind) {
        .actor_creation => .improves_with_cores,
        .actor_messaging => .degrades_with_cores,
        .mailbox_throughput => .improves_with_cores,
        .context_switching => .flat,
        .memory_allocation => .improves_with_cores,
        .component_startup => .flat,
        .scheduler_latency => .degrades_with_cores,
        .cross_core_messaging => .degrades_with_cores,
        .work_stealing => .degrades_with_cores,
        // Per-node capability manager (Prompt 28) makes lookup O(1)
        // local regardless of total node count.
        .capability_lookup => .flat,
    };
}

fn baseLatencyTicks(kind: metrics.BenchmarkKind) u64 {
    return switch (kind) {
        .actor_creation => 40,
        .actor_messaging => 25,
        .mailbox_throughput => 10,
        .context_switching => 5,
        .memory_allocation => 15,
        .component_startup => 200,
        .scheduler_latency => 8,
        .cross_core_messaging => 30,
        .work_stealing => 20,
        .capability_lookup => 6,
    };
}

fn baseOpsPerCore(kind: metrics.BenchmarkKind) u64 {
    return switch (kind) {
        .actor_creation => 1000,
        .actor_messaging => 800,
        .mailbox_throughput => 1500,
        .context_switching => 2000,
        .memory_allocation => 1200,
        .component_startup => 50,
        .scheduler_latency => 900,
        .cross_core_messaging => 600,
        .work_stealing => 400,
        .capability_lookup => 1800,
    };
}

/// Deterministic per-operation latency (in synthetic ticks) for a
/// given kind at a given core count.
pub fn latencyTicks(kind: metrics.BenchmarkKind, core_count: usize) u64 {
    const base = baseLatencyTicks(kind);
    return switch (profileFor(kind)) {
        .flat, .improves_with_cores => base,
        .degrades_with_cores => base + scale.log2Floor(core_count) * 2,
    };
}

/// Deterministic total operation count for a given kind at a given
/// core count, over a fixed measurement window.
pub fn operationCount(kind: metrics.BenchmarkKind, core_count: usize) u64 {
    const per_core = baseOpsPerCore(kind);
    return switch (profileFor(kind)) {
        .improves_with_cores => per_core * core_count,
        .flat => per_core,
        // Contention dampens ideal linear scaling slightly.
        .degrades_with_cores => (per_core * core_count * 9) / 10,
    };
}

const testing = @import("std").testing;

test "profileFor covers every BenchmarkKind" {
    for (metrics.benchmark_kinds) |kind| {
        _ = profileFor(kind);
    }
}

test "improves_with_cores kinds scale operationCount up with core_count" {
    const at1 = operationCount(.actor_creation, 1);
    const at128 = operationCount(.actor_creation, 128);
    try testing.expect(at128 > at1);
}

test "flat kinds keep latencyTicks constant across core counts" {
    const at1 = latencyTicks(.capability_lookup, 1);
    const at128 = latencyTicks(.capability_lookup, 128);
    try testing.expectEqual(at1, at128);
}

test "degrades_with_cores kinds have non-decreasing latencyTicks as core_count grows" {
    const at1 = latencyTicks(.cross_core_messaging, 1);
    const at128 = latencyTicks(.cross_core_messaging, 128);
    try testing.expect(at128 >= at1);
}
