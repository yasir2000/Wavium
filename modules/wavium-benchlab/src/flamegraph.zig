//! Minimal flame-graph data model: a tree of stack frames, each with
//! a "self ticks" cost (a synthetic op-count, not wall-clock time -
//! this freestanding runtime has no wall clock). A markdown/text
//! renderer walks this tree depth-first to emit an indented flame
//! graph, mirroring how tools like `perf script | flamegraph.pl`
//! render collapsed stacks, without depending on a real profiler.

pub const max_children = 16;

pub const FlameFrame = struct {
    name: []const u8,
    self_ticks: u64,
    child_count: usize = 0,
    children: [max_children]usize = undefined,
};

pub const FlameGraphError = error{
    TooManyFrames,
    TooManyChildren,
    InvalidParent,
};

pub const FlameGraph = struct {
    frames: [64]FlameFrame = undefined,
    frame_count: usize = 0,

    const Self = @This();

    pub fn init(root_name: []const u8) Self {
        var self: Self = .{ .frames = undefined, .frame_count = 0 };
        self.frames[0] = .{ .name = root_name, .self_ticks = 0 };
        self.frame_count = 1;
        return self;
    }

    pub fn root(self: *const Self) usize {
        _ = self;
        return 0;
    }

    pub fn addChild(self: *Self, parent: usize, name: []const u8, self_ticks: u64) FlameGraphError!usize {
        if (parent >= self.frame_count) return FlameGraphError.InvalidParent;
        if (self.frame_count >= self.frames.len) return FlameGraphError.TooManyFrames;
        if (self.frames[parent].child_count >= max_children) return FlameGraphError.TooManyChildren;

        const idx = self.frame_count;
        self.frames[idx] = .{ .name = name, .self_ticks = self_ticks };
        self.frame_count += 1;

        self.frames[parent].children[self.frames[parent].child_count] = idx;
        self.frames[parent].child_count += 1;
        return idx;
    }

    /// Total ticks for a frame including all descendants.
    pub fn totalTicks(self: *const Self, frame_idx: usize) u64 {
        var total = self.frames[frame_idx].self_ticks;
        var i: usize = 0;
        while (i < self.frames[frame_idx].child_count) : (i += 1) {
            total += self.totalTicks(self.frames[frame_idx].children[i]);
        }
        return total;
    }
};

const testing = @import("std").testing;

test "FlameGraph root starts with zero self ticks" {
    const fg = FlameGraph.init("suite_run");
    try testing.expectEqual(@as(u64, 0), fg.frames[fg.root()].self_ticks);
}

test "FlameGraph addChild builds a tree and totalTicks sums descendants" {
    var fg = FlameGraph.init("suite_run");
    const child1 = try fg.addChild(fg.root(), "actor_creation", 10);
    _ = try fg.addChild(child1, "spawn", 4);
    _ = try fg.addChild(fg.root(), "actor_messaging", 6);

    try testing.expectEqual(@as(u64, 20), fg.totalTicks(fg.root()));
}

test "FlameGraph addChild rejects an out-of-range parent" {
    var fg = FlameGraph.init("suite_run");
    try testing.expectError(FlameGraphError.InvalidParent, fg.addChild(99, "bad", 1));
}
