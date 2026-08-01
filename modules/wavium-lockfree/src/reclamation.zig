const std = @import("std");
const base = @import("ring_buffer.zig");

/// Epoch-based reclamation: participants (one per core, matching this
/// codebase's per-core runtime model) `enter`/`leave` a read-side critical
/// section stamped with the current global epoch. Freed resources are
/// `retire`d rather than reused immediately; `reclaim` only returns a
/// retired index once every participant that might still be observing an
/// older epoch has left, which is what makes it safe to recycle that index
/// (e.g. back into a LockFreeFreelist) without a use-after-free race.
pub fn EpochReclaimer(comptime max_participants: usize, comptime retire_capacity: usize) type {
    comptime {
        if (max_participants == 0) @compileError("max_participants must be > 0");
        if (retire_capacity == 0) @compileError("retire_capacity must be > 0");
    }

    return struct {
        const Self = @This();
        const no_epoch: u64 = std.math.maxInt(u64);

        global_epoch: std.atomic.Value(u64) align(base.cache_line_bytes),
        participant_epochs: [max_participants]std.atomic.Value(u64),
        retired_index: [retire_capacity]u32,
        retired_epoch: [retire_capacity]u64,
        retired_len: usize,

        pub fn init() Self {
            var self: Self = .{
                .global_epoch = std.atomic.Value(u64).init(0),
                .participant_epochs = undefined,
                .retired_index = undefined,
                .retired_epoch = undefined,
                .retired_len = 0,
            };
            for (&self.participant_epochs) |*e| e.* = std.atomic.Value(u64).init(no_epoch);
            return self;
        }

        /// Marks `participant` as active in the current global epoch. Must
        /// be paired with a later `leave` call before this participant's
        /// slot is reused for a different logical participant.
        pub fn enter(self: *Self, participant: usize) void {
            const epoch = self.global_epoch.load(.acquire);
            self.participant_epochs[participant].store(epoch, .release);
        }

        pub fn leave(self: *Self, participant: usize) void {
            self.participant_epochs[participant].store(no_epoch, .release);
        }

        pub const RetireError = error{RetireBufferFull};

        /// Records that `index` was logically removed during the current
        /// epoch; it cannot be safely reused until `reclaim` releases it.
        pub fn retire(self: *Self, index: u32) RetireError!void {
            if (self.retired_len >= retire_capacity) return error.RetireBufferFull;
            self.retired_index[self.retired_len] = index;
            self.retired_epoch[self.retired_len] = self.global_epoch.load(.acquire);
            self.retired_len += 1;
        }

        fn minActiveEpoch(self: *Self) ?u64 {
            var min: ?u64 = null;
            for (&self.participant_epochs) |*e| {
                const val = e.load(.acquire);
                if (val == no_epoch) continue;
                if (min == null or val < min.?) min = val;
            }
            return min;
        }

        /// Advances the global epoch, allowing older retirements to
        /// eventually become reclaimable once no participant still
        /// references them.
        pub fn advanceEpoch(self: *Self) void {
            _ = self.global_epoch.fetchAdd(1, .acq_rel);
        }

        /// Reclaims (moves into `out`) every retired index whose
        /// retirement epoch predates every currently active participant's
        /// epoch. Returns the number of indices reclaimed.
        pub fn reclaim(self: *Self, out: []u32) usize {
            const safe_epoch = self.minActiveEpoch() orelse std.math.maxInt(u64);
            var n: usize = 0;
            var i: usize = 0;
            while (i < self.retired_len) {
                if (self.retired_epoch[i] < safe_epoch and n < out.len) {
                    out[n] = self.retired_index[i];
                    n += 1;
                    self.retired_index[i] = self.retired_index[self.retired_len - 1];
                    self.retired_epoch[i] = self.retired_epoch[self.retired_len - 1];
                    self.retired_len -= 1;
                } else {
                    i += 1;
                }
            }
            return n;
        }
    };
}

test "reclaim withholds retirements while a participant is still in an old epoch" {
    var er = EpochReclaimer(2, 8).init();
    er.enter(0); // participant 0 active in epoch 0

    er.advanceEpoch(); // global epoch now 1
    try er.retire(42); // retired while global epoch was 1

    var out: [4]u32 = undefined;
    // participant 0 is still stuck in epoch 0, which predates the retirement
    try std.testing.expectEqual(@as(usize, 0), er.reclaim(out[0..]));

    er.leave(0);
    try std.testing.expectEqual(@as(usize, 1), er.reclaim(out[0..]));
    try std.testing.expectEqual(@as(u32, 42), out[0]);
}

test "reclaim returns retirements immediately when no participants are active" {
    var er = EpochReclaimer(2, 8).init();
    try er.retire(1);
    try er.retire(2);

    var out: [4]u32 = undefined;
    try std.testing.expectEqual(@as(usize, 2), er.reclaim(out[0..]));
}

test "retire reports RetireBufferFull once the retirement buffer is exhausted" {
    var er = EpochReclaimer(1, 2).init();
    try er.retire(1);
    try er.retire(2);
    try std.testing.expectError(error.RetireBufferFull, er.retire(3));
}
