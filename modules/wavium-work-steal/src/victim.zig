//! Victim selection: idle workers pick a (usually randomized) target
//! worker to attempt a steal from. Randomization is what gives the
//! overall scheduler its fairness against victims - always picking
//! the same busiest worker would concentrate contention and starve
//! that one worker's local `popBottom` fast path.

const std = @import("std");
const testing = std.testing;

pub const WorkerId = u16;

/// A tiny, dependency-free xorshift32 PRNG. This is a freestanding
/// runtime with no OS entropy source, so callers seed this themselves
/// (e.g. from a per-core timestamp counter or boot-time counter).
pub const Rng = struct {
    state: u32,

    pub fn init(seed: u32) Rng {
        return .{ .state = if (seed == 0) 0xA5A5A5A5 else seed };
    }

    pub fn next(self: *Rng) u32 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 17;
        x ^= x << 5;
        self.state = x;
        return x;
    }

    pub fn nextBelow(self: *Rng, bound: u32) u32 {
        return self.next() % bound;
    }
};

/// Picks a random worker id in `[0, worker_count)` other than
/// `self_id`. Returns `null` if there is no other worker to steal
/// from (`worker_count <= 1`).
pub fn selectRandomVictim(rng: *Rng, self_id: WorkerId, worker_count: usize) ?WorkerId {
    if (worker_count <= 1) return null;
    var candidate: usize = rng.nextBelow(@intCast(worker_count));
    if (candidate == self_id) {
        candidate = (candidate + 1) % worker_count;
    }
    return @intCast(candidate);
}

/// Picks the worker with the largest `approxLen` from `loads`,
/// excluding `self_id`. Useful when randomized selection should be
/// biased toward the busiest worker rather than a uniform pick.
pub fn selectBusiestVictim(self_id: WorkerId, loads: []const usize) ?WorkerId {
    var best: ?WorkerId = null;
    var best_len: usize = 0;
    for (loads, 0..) |len, i| {
        const id: WorkerId = @intCast(i);
        if (id == self_id) continue;
        if (len > best_len or best == null) {
            best = id;
            best_len = len;
        }
    }
    return best;
}

test "selectRandomVictim never returns the caller's own id" {
    var rng = Rng.init(42);
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const victim = selectRandomVictim(&rng, 3, 8).?;
        try testing.expect(victim != 3);
        try testing.expect(victim < 8);
    }
}

test "selectRandomVictim returns null with fewer than two workers" {
    var rng = Rng.init(1);
    try testing.expect(selectRandomVictim(&rng, 0, 1) == null);
}

test "selectBusiestVictim picks the largest non-self queue" {
    const loads = [_]usize{ 2, 10, 5 };
    try testing.expectEqual(@as(WorkerId, 1), selectBusiestVictim(0, &loads).?);
}

test "selectBusiestVictim excludes the caller even if it is busiest" {
    const loads = [_]usize{ 99, 1, 2 };
    try testing.expectEqual(@as(WorkerId, 2), selectBusiestVictim(0, &loads).?);
}
