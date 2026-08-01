//! Markdown report generator: renders a `BenchmarkSuite`'s results
//! into a fixed caller-supplied buffer (no allocator dependency,
//! matching this repo's freestanding-safe convention - see
//! `wavium-build`'s `appendSlice`/`appendU64` pattern, reimplemented
//! locally to stay decoupled).

const std = @import("std");
const metrics = @import("metrics.zig");
const suite_mod = @import("suite.zig");

pub const ReportError = error{BufferTooSmall};

fn appendSlice(out: []u8, pos: *usize, data: []const u8) ReportError!void {
    const end = pos.* + data.len;
    if (end > out.len) return ReportError.BufferTooSmall;
    @memcpy(out[pos.*..end], data);
    pos.* = end;
}

fn appendU64(out: []u8, pos: *usize, value: u64) ReportError!void {
    var num_buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(num_buf[0..], "{d}", .{value}) catch return ReportError.BufferTooSmall;
    try appendSlice(out, pos, s);
}

/// Renders a Markdown table: one row per (kind, core_count) result,
/// with operations, throughput (ops per 1000 ticks), and p50/p99
/// latency (ticks). Returns the number of bytes written into `out`.
pub fn generateMarkdownReport(results: []const suite_mod.BenchmarkResult, out: []u8) ReportError!usize {
    var pos: usize = 0;

    try appendSlice(out, &pos, "# Performance & Scalability Lab Report\n\n");
    try appendSlice(out, &pos, "| Benchmark | Cores | Operations | Throughput (ops/1000 ticks) | p50 latency | p99 latency |\n");
    try appendSlice(out, &pos, "| --- | --- | --- | --- | --- | --- |\n");

    for (results) |r| {
        try appendSlice(out, &pos, "| ");
        try appendSlice(out, &pos, metrics.kindName(r.kind));
        try appendSlice(out, &pos, " | ");
        try appendU64(out, &pos, r.core_count);
        try appendSlice(out, &pos, " | ");
        try appendU64(out, &pos, r.operations);
        try appendSlice(out, &pos, " | ");
        try appendU64(out, &pos, r.tput.opsPerThousandTicks());
        try appendSlice(out, &pos, " | ");
        try appendU64(out, &pos, r.hist.percentile(50));
        try appendSlice(out, &pos, " | ");
        try appendU64(out, &pos, r.hist.percentile(99));
        try appendSlice(out, &pos, " |\n");
    }

    return pos;
}

const testing = @import("std").testing;

test "generateMarkdownReport renders a header and one row per result" {
    var suite = suite_mod.BenchmarkSuite.init();
    try suite.runOne(.actor_creation, 8);
    try suite.runOne(.capability_lookup, 16);

    var buf: [4096]u8 = undefined;
    const n = try generateMarkdownReport(suite.resultSlice(), &buf);
    const text = buf[0..n];

    try testing.expect(std.mem.indexOf(u8, text, "# Performance & Scalability Lab Report") != null);
    try testing.expect(std.mem.indexOf(u8, text, "actor_creation") != null);
    try testing.expect(std.mem.indexOf(u8, text, "capability_lookup") != null);
}

test "generateMarkdownReport reports BufferTooSmall for an undersized buffer" {
    var suite = suite_mod.BenchmarkSuite.init();
    try suite.runOne(.actor_creation, 8);

    var buf: [8]u8 = undefined;
    try testing.expectError(ReportError.BufferTooSmall, generateMarkdownReport(suite.resultSlice(), &buf));
}
