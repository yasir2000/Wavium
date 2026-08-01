//! The 10 measurements this prompt requires the benchmark suite to
//! cover.

pub const BenchmarkKind = enum(u4) {
    actor_creation,
    actor_messaging,
    mailbox_throughput,
    context_switching,
    memory_allocation,
    component_startup,
    scheduler_latency,
    cross_core_messaging,
    work_stealing,
    capability_lookup,
};

pub const benchmark_kinds = [_]BenchmarkKind{
    .actor_creation,
    .actor_messaging,
    .mailbox_throughput,
    .context_switching,
    .memory_allocation,
    .component_startup,
    .scheduler_latency,
    .cross_core_messaging,
    .work_stealing,
    .capability_lookup,
};

pub fn kindName(kind: BenchmarkKind) []const u8 {
    return switch (kind) {
        .actor_creation => "actor_creation",
        .actor_messaging => "actor_messaging",
        .mailbox_throughput => "mailbox_throughput",
        .context_switching => "context_switching",
        .memory_allocation => "memory_allocation",
        .component_startup => "component_startup",
        .scheduler_latency => "scheduler_latency",
        .cross_core_messaging => "cross_core_messaging",
        .work_stealing => "work_stealing",
        .capability_lookup => "capability_lookup",
    };
}

const testing = @import("std").testing;

test "benchmark_kinds lists exactly the 10 required measurements" {
    try testing.expectEqual(@as(usize, 10), benchmark_kinds.len);
}

test "kindName covers every BenchmarkKind" {
    for (benchmark_kinds) |kind| {
        try testing.expect(kindName(kind).len > 0);
    }
}
