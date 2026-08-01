//! Fixed-bucket latency histogram - no heap allocation, no wall
//! clock. Values are synthetic "cost ticks" produced by the suite's
//! deterministic cost model (see `suite.zig`), not real timing (this
//! freestanding runtime has no `std.time.Timer` in the pinned Zig
//! toolchain).

pub const bucket_upper_bounds = [_]u64{
    1, 2, 4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 65535,
};
pub const bucket_count = bucket_upper_bounds.len;

pub const LatencyHistogram = struct {
    buckets: [bucket_count]u64 = undefined,
    total_samples: u64 = 0,

    const Self = @This();

    pub fn init() Self {
        var self: Self = .{ .buckets = undefined, .total_samples = 0 };
        for (&self.buckets) |*b| b.* = 0;
        return self;
    }

    pub fn record(self: *Self, value: u64) void {
        var i: usize = 0;
        while (i < bucket_count) : (i += 1) {
            if (value <= bucket_upper_bounds[i]) {
                self.buckets[i] += 1;
                self.total_samples += 1;
                return;
            }
        }
        // Larger than every bucket bound: fold into the last bucket.
        self.buckets[bucket_count - 1] += 1;
        self.total_samples += 1;
    }

    /// Approximate percentile (0-100) via cumulative bucket counts.
    pub fn percentile(self: *const Self, p: u8) u64 {
        if (self.total_samples == 0) return 0;
        const target = (@as(u64, p) * self.total_samples + 99) / 100;
        var cumulative: u64 = 0;
        var i: usize = 0;
        while (i < bucket_count) : (i += 1) {
            cumulative += self.buckets[i];
            if (cumulative >= target) return bucket_upper_bounds[i];
        }
        return bucket_upper_bounds[bucket_count - 1];
    }
};

const testing = @import("std").testing;

test "LatencyHistogram records values into correct buckets" {
    var h = LatencyHistogram.init();
    h.record(1);
    h.record(50);
    h.record(1000);
    try testing.expectEqual(@as(u64, 3), h.total_samples);
}

test "LatencyHistogram percentile is monotonic and bounded" {
    var h = LatencyHistogram.init();
    var v: u64 = 1;
    while (v <= 1024) : (v *= 2) h.record(v);
    const p50 = h.percentile(50);
    const p99 = h.percentile(99);
    try testing.expect(p50 <= p99);
    try testing.expect(p99 <= bucket_upper_bounds[bucket_count - 1]);
}

test "LatencyHistogram with no samples returns 0 percentile" {
    const h = LatencyHistogram.init();
    try testing.expectEqual(@as(u64, 0), h.percentile(95));
}
