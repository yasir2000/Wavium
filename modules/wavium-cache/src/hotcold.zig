//! Hot/cold data separation - the classic technique of splitting a
//! logical record into a small, frequently-accessed "hot" part and a
//! larger, rarely-accessed "cold" part, stored in separate
//! structure-of-arrays regions. Iterating the hot data then touches far
//! fewer cache lines than an array-of-structs layout would, because the
//! cold fields (which the hot loop never reads) are not interleaved in
//! between hot elements.

/// A fixed-capacity, allocator-free structure-of-arrays store that
/// keeps `Hot` and `Cold` records for the same logical entities in two
/// separate arrays, indexed in lock-step.
pub fn HotColdArray(comptime Hot: type, comptime Cold: type, comptime capacity: usize) type {
    return struct {
        hot: [capacity]Hot = undefined,
        cold: [capacity]Cold = undefined,
        count: usize = 0,

        const Self = @This();

        pub fn init() Self {
            return .{};
        }

        /// Appends a new entity's hot and cold records. Returns the
        /// assigned index.
        pub fn append(self: *Self, hot: Hot, cold: Cold) HotColdError!usize {
            if (self.count >= capacity) return HotColdError.Full;
            const index = self.count;
            self.hot[index] = hot;
            self.cold[index] = cold;
            self.count += 1;
            return index;
        }

        pub fn hotPtr(self: *Self, index: usize) *Hot {
            return &self.hot[index];
        }

        pub fn coldPtr(self: *Self, index: usize) *Cold {
            return &self.cold[index];
        }

        /// The slice of hot records currently in use - iterating this
        /// alone (the common "hot loop") never touches cold memory.
        pub fn hotSlice(self: *Self) []Hot {
            return self.hot[0..self.count];
        }

        pub fn coldSlice(self: *Self) []Cold {
            return self.cold[0..self.count];
        }

        pub fn len(self: *const Self) usize {
            return self.count;
        }
    };
}

pub const HotColdError = error{Full};

const testing = @import("std").testing;

test "HotColdArray keeps hot and cold records index-aligned" {
    const Hot = struct { active: bool, priority: u8 };
    const Cold = struct { name: [16]u8, description: [64]u8 };

    var store = HotColdArray(Hot, Cold, 4).init();
    const idx = try store.append(.{ .active = true, .priority = 5 }, .{ .name = undefined, .description = undefined });
    try testing.expectEqual(@as(usize, 0), idx);
    try testing.expectEqual(@as(usize, 1), store.len());
    try testing.expect(store.hotPtr(idx).active);
    try testing.expectEqual(@as(u8, 5), store.hotPtr(idx).priority);
}

test "HotColdArray hot record is far smaller than combined record" {
    const Hot = struct { active: bool, priority: u8 };
    const Cold = struct { name: [64]u8, description: [256]u8 };

    try testing.expect(@sizeOf(Hot) < @sizeOf(Cold));

    var store = HotColdArray(Hot, Cold, 8).init();
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        _ = try store.append(.{ .active = i % 2 == 0, .priority = @intCast(i) }, .{ .name = undefined, .description = undefined });
    }

    // The "hot loop" - summing priorities - only ever touches the
    // compact hot array, never the much larger cold array.
    var sum: usize = 0;
    for (store.hotSlice()) |h| sum += h.priority;
    try testing.expectEqual(@as(usize, 0 + 1 + 2 + 3 + 4 + 5 + 6 + 7), sum);
}

test "HotColdArray reports Full once capacity is exhausted" {
    const Hot = struct { value: u32 };
    const Cold = struct { blob: [8]u8 };

    var store = HotColdArray(Hot, Cold, 2).init();
    _ = try store.append(.{ .value = 1 }, .{ .blob = undefined });
    _ = try store.append(.{ .value = 2 }, .{ .blob = undefined });
    try testing.expectError(HotColdError.Full, store.append(.{ .value = 3 }, .{ .blob = undefined }));
}
