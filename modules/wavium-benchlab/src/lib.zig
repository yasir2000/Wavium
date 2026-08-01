//! wavium-benchlab: comprehensive benchmark suite covering the 10
//! required measurements (actor creation, actor messaging, mailbox
//! throughput, context switching, memory allocation, component
//! startup, scheduler latency, cross-core messaging, work stealing,
//! capability lookup) across the 8 required scale points (1-128
//! CPUs), producing latency histograms, throughput samples, flame
//! graph data, and Markdown reports.

pub const metrics = @import("metrics.zig");
pub const scale = @import("scale.zig");
pub const histogram = @import("histogram.zig");
pub const flamegraph = @import("flamegraph.zig");
pub const throughput = @import("throughput.zig");
pub const cost_model = @import("cost_model.zig");
pub const suite = @import("suite.zig");
pub const report = @import("report.zig");

pub const BenchmarkKind = metrics.BenchmarkKind;
pub const LatencyHistogram = histogram.LatencyHistogram;
pub const FlameGraph = flamegraph.FlameGraph;
pub const ThroughputSample = throughput.ThroughputSample;
pub const BenchmarkSuite = suite.BenchmarkSuite;
pub const BenchmarkResult = suite.BenchmarkResult;

pub fn moduleName() []const u8 {
    return "wavium-benchlab";
}

const testing = @import("std").testing;
const std = @import("std");

test "moduleName" {
    try testing.expectEqualStrings("wavium-benchlab", moduleName());
}

test "end-to-end: full 10x8 benchmark matrix, flame graph, and markdown report" {
    var bench_suite = BenchmarkSuite.init();
    try bench_suite.runFullMatrix();
    try testing.expectEqual(suite.max_results, bench_suite.result_count);

    // Flame graph over the suite run: one child frame per benchmark
    // kind, self ticks derived from the 128-core operation count.
    var fg = FlameGraph.init("performance_scalability_lab");
    for (metrics.benchmark_kinds) |kind| {
        var ops_at_128: u64 = 0;
        for (bench_suite.resultSlice()) |r| {
            if (r.kind == kind and r.core_count == 128) ops_at_128 = r.operations;
        }
        _ = try fg.addChild(fg.root(), metrics.kindName(kind), ops_at_128);
    }
    try testing.expectEqual(metrics.benchmark_kinds.len, fg.frames[fg.root()].child_count);
    try testing.expect(fg.totalTicks(fg.root()) > 0);

    // Markdown report covers every kind name.
    var buf: [1024 * 32]u8 = undefined;
    const n = try report.generateMarkdownReport(bench_suite.resultSlice(), &buf);
    const text = buf[0..n];
    for (metrics.benchmark_kinds) |kind| {
        try testing.expect(std.mem.indexOf(u8, text, metrics.kindName(kind)) != null);
    }
}
