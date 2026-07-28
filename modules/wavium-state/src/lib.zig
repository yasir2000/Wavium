const std = @import("std");

pub const ActorStateRecord = struct {
    actor_id: u64,
    version: u64,
    bytes: []const u8,
};

pub const StateLog = struct {
    allocator: std.mem.Allocator,
    entries: std.ArrayListUnmanaged(OwnedEntry),

    const OwnedEntry = struct {
        actor_id: u64,
        version: u64,
        bytes: []u8,
    };

    pub fn init(allocator: std.mem.Allocator) StateLog {
        return .{
            .allocator = allocator,
            .entries = .empty,
        };
    }

    pub fn deinit(self: *StateLog) void {
        for (self.entries.items) |e| self.allocator.free(e.bytes);
        self.entries.deinit(self.allocator);
    }

    pub fn append(self: *StateLog, record: ActorStateRecord) !void {
        const owned = try self.allocator.dupe(u8, record.bytes);
        try self.entries.append(self.allocator, .{
            .actor_id = record.actor_id,
            .version = record.version,
            .bytes = owned,
        });
    }

    pub fn latestForActor(self: *StateLog, actor_id: u64) ?ActorStateRecord {
        var i = self.entries.items.len;
        while (i > 0) {
            i -= 1;
            const e = self.entries.items[i];
            if (e.actor_id == actor_id) {
                return .{ .actor_id = e.actor_id, .version = e.version, .bytes = e.bytes };
            }
        }
        return null;
    }

    pub fn replay(self: *StateLog, actor_id: u64, out: []ActorStateRecord) usize {
        var out_ix: usize = 0;
        for (self.entries.items) |e| {
            if (e.actor_id != actor_id) continue;
            if (out_ix >= out.len) break;
            out[out_ix] = .{ .actor_id = e.actor_id, .version = e.version, .bytes = e.bytes };
            out_ix += 1;
        }
        return out_ix;
    }

    pub fn serializeSnapshot(self: *StateLog, allocator: std.mem.Allocator) ![]u8 {
        var total: usize = 4;
        for (self.entries.items) |e| {
            total += 8 + 8 + 4 + e.bytes.len;
        }

        const out = try allocator.alloc(u8, total);
        var ix: usize = 0;

        const count_ptr: *[4]u8 = @ptrCast(out[ix .. ix + 4].ptr);
        std.mem.writeInt(u32, count_ptr, @intCast(self.entries.items.len), .little);
        ix += 4;

        for (self.entries.items) |e| {
            const actor_ptr: *[8]u8 = @ptrCast(out[ix .. ix + 8].ptr);
            std.mem.writeInt(u64, actor_ptr, e.actor_id, .little);
            ix += 8;
            const version_ptr: *[8]u8 = @ptrCast(out[ix .. ix + 8].ptr);
            std.mem.writeInt(u64, version_ptr, e.version, .little);
            ix += 8;
            if (e.bytes.len > std.math.maxInt(u32)) return error.RecordTooLarge;
            const len_ptr: *[4]u8 = @ptrCast(out[ix .. ix + 4].ptr);
            std.mem.writeInt(u32, len_ptr, @intCast(e.bytes.len), .little);
            ix += 4;
            @memcpy(out[ix .. ix + e.bytes.len], e.bytes);
            ix += e.bytes.len;
        }

        return out;
    }

    pub fn replaySnapshot(self: *StateLog, snapshot: []const u8) !void {
        if (snapshot.len < 4) return error.InvalidSnapshot;

        var ix: usize = 0;
        const count_ptr: *const [4]u8 = @ptrCast(snapshot[ix .. ix + 4].ptr);
        const count = std.mem.readInt(u32, count_ptr, .little);
        ix += 4;

        var i: u32 = 0;
        while (i < count) : (i += 1) {
            if (snapshot.len < ix + 20) return error.InvalidSnapshot;

            const actor_ptr: *const [8]u8 = @ptrCast(snapshot[ix .. ix + 8].ptr);
            const actor_id = std.mem.readInt(u64, actor_ptr, .little);
            ix += 8;
            const version_ptr: *const [8]u8 = @ptrCast(snapshot[ix .. ix + 8].ptr);
            const version = std.mem.readInt(u64, version_ptr, .little);
            ix += 8;
            const len_ptr: *const [4]u8 = @ptrCast(snapshot[ix .. ix + 4].ptr);
            const len = std.mem.readInt(u32, len_ptr, .little);
            ix += 4;

            const end_ix = ix + len;
            if (snapshot.len < end_ix) return error.InvalidSnapshot;
            try self.append(.{ .actor_id = actor_id, .version = version, .bytes = snapshot[ix..end_ix] });
            ix = end_ix;
        }
    }
};

test "state record stores actor id" {
    const rec = ActorStateRecord{ .actor_id = 1, .version = 0, .bytes = "s" };
    try std.testing.expectEqual(@as(u64, 1), rec.actor_id);
}

test "append-only state log latest and replay" {
    var log = StateLog.init(std.testing.allocator);
    defer log.deinit();

    try log.append(.{ .actor_id = 9, .version = 1, .bytes = "v1" });
    try log.append(.{ .actor_id = 9, .version = 2, .bytes = "v2" });
    try log.append(.{ .actor_id = 3, .version = 1, .bytes = "other" });

    const latest = log.latestForActor(9).?;
    try std.testing.expectEqual(@as(u64, 2), latest.version);
    try std.testing.expectEqualStrings("v2", latest.bytes);

    var replay_buf: [4]ActorStateRecord = undefined;
    const n = log.replay(9, replay_buf[0..]);
    try std.testing.expectEqual(@as(usize, 2), n);
    try std.testing.expectEqual(@as(u64, 1), replay_buf[0].version);
    try std.testing.expectEqual(@as(u64, 2), replay_buf[1].version);
}

test "snapshot serialize and replay roundtrip" {
    var src = StateLog.init(std.testing.allocator);
    defer src.deinit();

    try src.append(.{ .actor_id = 1, .version = 1, .bytes = "a1" });
    try src.append(.{ .actor_id = 2, .version = 1, .bytes = "b1" });
    try src.append(.{ .actor_id = 1, .version = 2, .bytes = "a2" });

    const snapshot = try src.serializeSnapshot(std.testing.allocator);
    defer std.testing.allocator.free(snapshot);

    var dst = StateLog.init(std.testing.allocator);
    defer dst.deinit();
    try dst.replaySnapshot(snapshot);

    const latest = dst.latestForActor(1).?;
    try std.testing.expectEqual(@as(u64, 2), latest.version);
    try std.testing.expectEqualStrings("a2", latest.bytes);
}
