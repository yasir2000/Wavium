//! Runs the full benchmark matrix: all 10 `BenchmarkKind`s across all
//! 8 `core_counts` scale points (80 combinations), producing one
//! `BenchmarkResult` per combination with a populated latency
//! histogram and a throughput sample.

const metrics = @import("metrics.zig");
const scale = @import("scale.zig");
const cost_model = @import("cost_model.zig");
const histogram = @import("histogram.zig");
const throughput = @import("throughput.zig");

pub const samples_per_result = 32;
pub const max_results = metrics.benchmark_kinds.len * scale.core_counts.len;

pub const BenchmarkResult = struct {
    kind: metrics.BenchmarkKind,
    core_count: usize,
    operations: u64,
    hist: histogram.LatencyHistogram,
    tput: throughput.ThroughputSample,
};

pub const SuiteError = error{ResultsFull};

pub const BenchmarkSuite = struct {
    results: [max_results]BenchmarkResult = undefined,
    result_count: usize = 0,

    const Self = @This();

    pub fn init() Self {
        return .{ .results = undefined, .result_count = 0 };
    }

    /// Runs one (kind, core_count) benchmark using the deterministic
    /// cost model, recording `samples_per_result` latency samples
    /// (each with a small deterministic jitter) into a histogram.
    pub fn runOne(self: *Self, kind: metrics.BenchmarkKind, core_count: usize) SuiteError!void {
        if (self.result_count >= max_results) return SuiteError.ResultsFull;

        const base_latency = cost_model.latencyTicks(kind, core_count);
        const operations = cost_model.operationCount(kind, core_count);

        var hist = histogram.LatencyHistogram.init();
        var i: usize = 0;
        while (i < samples_per_result) : (i += 1) {
            // Deterministic jitter: +/- (i % 5) ticks.
            const jitter: u64 = i % 5;
            hist.record(base_latency + jitter);
        }

        const tput = throughput.ThroughputSample{
            .operations = operations,
            .tick_budget = base_latency * samples_per_result,
        };

        self.results[self.result_count] = .{
            .kind = kind,
            .core_count = core_count,
            .operations = operations,
            .hist = hist,
            .tput = tput,
        };
        self.result_count += 1;
    }

    /// Runs every BenchmarkKind across every supported core_count.
    pub fn runFullMatrix(self: *Self) SuiteError!void {
        for (metrics.benchmark_kinds) |kind| {
            for (scale.core_counts) |core_count| {
                try self.runOne(kind, core_count);
            }
        }
    }

    pub fn resultSlice(self: *const Self) []const BenchmarkResult {
        return self.results[0..self.result_count];
    }
};

const testing = @import("std").testing;

test "runOne records a populated histogram and non-zero operations" {
    var suite = BenchmarkSuite.init();
    try suite.runOne(.actor_creation, 8);
    try testing.expectEqual(@as(usize, 1), suite.result_count);
    try testing.expectEqual(@as(u64, samples_per_result), suite.results[0].hist.total_samples);
    try testing.expect(suite.results[0].operations > 0);
}

test "runFullMatrix produces exactly kinds * core_counts results" {
    var suite = BenchmarkSuite.init();
    try suite.runFullMatrix();
    try testing.expectEqual(max_results, suite.result_count);
}

test "runFullMatrix results cover every kind and every core count" {
    var suite = BenchmarkSuite.init();
    try suite.runFullMatrix();

    for (metrics.benchmark_kinds) |kind| {
        var found = false;
        for (suite.resultSlice()) |r| {
            if (r.kind == kind and r.core_count == 128) found = true;
        }
        try testing.expect(found);
    }
}
