//! Performance benchmarks for the work-stealing scheduler, as
//! required by the prompt ("Generate performance benchmarks"). As
//! with every other benchmark in this repository, there are no OS
//! threads in this freestanding runtime, so concurrent stealing is
//! simulated single-threaded: each simulated tick lets every worker
//! either drain its own queue or attempt one steal, and elapsed time
//! is measured with `std.time.Timer`. This still exercises the exact
//! same push/pop/steal code paths that would run under real
//! concurrency; it measures single-threaded overhead, not contention.

const std = @import("std");
const testing = std.testing;
const worker_mod = @import("worker.zig");

const bench_capacity = 256;
const BenchWorker = worker_mod.Worker(bench_capacity);

pub const BenchmarkResult = struct {
    worker_count: usize,
    actors_per_worker: usize,
    total_processed: usize,
    elapsed_ns: u64,
};

/// Seeds `worker_count` workers with `actors_per_worker` actors each
/// (all on worker 0, the worst case for load imbalance) and then lets
/// every worker alternate between servicing its own queue and
/// attempting a steal until all actors have been processed.
pub fn runSuite(worker_count: usize, actors_per_worker: usize) BenchmarkResult {
    var workers: [max_workers]BenchWorker = undefined;
    var i: usize = 0;
    while (i < worker_count) : (i += 1) {
        workers[i] = BenchWorker.init(@intCast(i), @intCast(i * 2654435761 + 1));
    }

    const total = worker_count * actors_per_worker;
    var seeded: usize = 0;
    while (seeded < total) : (seeded += 1) {
        // All work starts on worker 0 - the maximally imbalanced case
        // that forces every other worker to steal.
        workers[0].submit(.{ .actor_id = @intCast(seeded), .priority = .normal }) catch break;
    }

    var timer = std.time.Timer.start() catch unreachable;

    var processed: usize = 0;
    var stalled_rounds: usize = 0;
    while (processed < total and stalled_rounds < 4) {
        var progressed = false;
        var w: usize = 0;
        while (w < worker_count) : (w += 1) {
            if (workers[w].popOwn()) |_| {
                processed += 1;
                progressed = true;
                continue;
            }
            if (workers[w].stealFrom(workers[0..worker_count])) |_| {
                processed += 1;
                progressed = true;
            }
        }
        stalled_rounds = if (progressed) 0 else stalled_rounds + 1;
    }

    const elapsed_ns = timer.lap();
    return .{
        .worker_count = worker_count,
        .actors_per_worker = actors_per_worker,
        .total_processed = processed,
        .elapsed_ns = elapsed_ns,
    };
}

/// Worker counts exercised by the benchmark suite's tests below.
pub const benchmark_worker_counts = [_]usize{ 1, 2, 8, 32 };
const max_workers = 32;

test "runSuite drains all seeded actors for a single worker" {
    const result = runSuite(1, 16);
    try testing.expectEqual(@as(usize, 16), result.total_processed);
}

test "runSuite drains all seeded actors across multiple stealing workers" {
    inline for (benchmark_worker_counts) |count| {
        const result = runSuite(count, 8);
        try testing.expectEqual(count * 8, result.total_processed);
    }
    // Wall-clock timings are environment-dependent; only assert every
    // actor was eventually processed, avoiding flaky CI timing
    // assertions (same convention as every other benchmark.zig in
    // this repository).
}
