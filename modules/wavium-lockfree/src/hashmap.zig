const std = @import("std");

/// Fixed-capacity lock-free concurrent hash map using open addressing with
/// linear probing. Each slot has an atomic state (`empty` -> `reserved` ->
/// `occupied`, or `tombstone` after removal) so a CAS on the state word is
/// enough to claim a slot without a lock; the key/value themselves are
/// written only by whichever inserter won that CAS.
pub fn ConcurrentHashMap(
    comptime K: type,
    comptime V: type,
    comptime capacity: usize,
    comptime hashFn: fn (K) u64,
    comptime eqFn: fn (K, K) bool,
) type {
    comptime {
        if (capacity == 0) @compileError("ConcurrentHashMap capacity must be > 0");
    }

    const State = enum(u8) {
        empty = 0,
        reserved = 1,
        occupied = 2,
        tombstone = 3,
    };

    return struct {
        const Self = @This();

        const Slot = struct {
            state: std.atomic.Value(u8),
            key: K,
            value: V,
        };

        slots: [capacity]Slot,

        pub fn init() Self {
            var self: Self = .{ .slots = undefined };
            for (&self.slots) |*s| {
                s.state = std.atomic.Value(u8).init(@intFromEnum(State.empty));
            }
            return self;
        }

        fn indexFor(key: K) usize {
            return @intCast(hashFn(key) % capacity);
        }

        /// Inserts or updates `key` -> `value`. Returns false if the map is
        /// full and no slot for this key could be claimed.
        pub fn insert(self: *Self, key: K, value: V) bool {
            var idx = indexFor(key);
            var probes: usize = 0;
            while (probes < capacity) : (probes += 1) {
                const slot = &self.slots[idx];
                const state = slot.state.load(.acquire);

                if (state == @intFromEnum(State.empty) or state == @intFromEnum(State.tombstone)) {
                    if (slot.state.cmpxchgStrong(state, @intFromEnum(State.reserved), .acq_rel, .acquire) == null) {
                        slot.key = key;
                        slot.value = value;
                        slot.state.store(@intFromEnum(State.occupied), .release);
                        return true;
                    }
                    continue; // lost the race for this slot; retry it
                } else if (state == @intFromEnum(State.occupied) and eqFn(slot.key, key)) {
                    slot.value = value;
                    return true;
                }

                idx = (idx + 1) % capacity;
            }
            return false;
        }

        pub fn get(self: *Self, key: K) ?V {
            var idx = indexFor(key);
            var probes: usize = 0;
            while (probes < capacity) : (probes += 1) {
                const slot = &self.slots[idx];
                const state = slot.state.load(.acquire);
                if (state == @intFromEnum(State.empty)) return null;
                if (state == @intFromEnum(State.occupied) and eqFn(slot.key, key)) return slot.value;
                idx = (idx + 1) % capacity;
            }
            return null;
        }

        pub fn contains(self: *Self, key: K) bool {
            return self.get(key) != null;
        }

        pub fn remove(self: *Self, key: K) bool {
            var idx = indexFor(key);
            var probes: usize = 0;
            while (probes < capacity) : (probes += 1) {
                const slot = &self.slots[idx];
                const state = slot.state.load(.acquire);
                if (state == @intFromEnum(State.empty)) return false;
                if (state == @intFromEnum(State.occupied) and eqFn(slot.key, key)) {
                    slot.state.store(@intFromEnum(State.tombstone), .release);
                    return true;
                }
                idx = (idx + 1) % capacity;
            }
            return false;
        }
    };
}

fn u32Hash(key: u32) u64 {
    return std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
}
fn u32Eq(a: u32, b: u32) bool {
    return a == b;
}

test "insert/get/contains round trip" {
    var m = ConcurrentHashMap(u32, []const u8, 16, u32Hash, u32Eq).init();
    try std.testing.expect(m.insert(1, "one"));
    try std.testing.expect(m.insert(2, "two"));

    try std.testing.expectEqualStrings("one", m.get(1).?);
    try std.testing.expect(m.contains(2));
    try std.testing.expect(!m.contains(3));
}

test "insert updates value for an existing key" {
    var m = ConcurrentHashMap(u32, u32, 16, u32Hash, u32Eq).init();
    try std.testing.expect(m.insert(5, 100));
    try std.testing.expect(m.insert(5, 200));
    try std.testing.expectEqual(@as(u32, 200), m.get(5).?);
}

test "remove tombstones a slot and frees it for reinsertion" {
    var m = ConcurrentHashMap(u32, u32, 4, u32Hash, u32Eq).init();
    try std.testing.expect(m.insert(1, 10));
    try std.testing.expect(m.remove(1));
    try std.testing.expect(!m.contains(1));
    try std.testing.expect(m.insert(1, 20));
    try std.testing.expectEqual(@as(u32, 20), m.get(1).?);
}

test "insert fails once the map is completely full" {
    var m = ConcurrentHashMap(u32, u32, 2, u32Hash, u32Eq).init();
    try std.testing.expect(m.insert(1, 1));
    try std.testing.expect(m.insert(2, 2));
    try std.testing.expect(!m.insert(3, 3));
}
