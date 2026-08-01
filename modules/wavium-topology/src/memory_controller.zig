//! Memory controller discovery: which NUMA node each on-chip memory
//! controller belongs to, and its advertised capacity.

const ids = @import("ids.zig");

pub const MemoryControllerId = u16;

pub const MemoryController = struct {
    id: MemoryControllerId,
    numa_node: ids.NumaNodeId,
    capacity_bytes: usize,
};

pub const MemoryControllerError = error{ TooManyControllers, NotFound };

pub const max_memory_controllers = 32;

pub const MemoryControllerTable = struct {
    controllers: [max_memory_controllers]MemoryController = undefined,
    count: usize = 0,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn add(self: *Self, id: MemoryControllerId, numa_node: ids.NumaNodeId, capacity_bytes: usize) MemoryControllerError!void {
        if (self.count >= max_memory_controllers) return MemoryControllerError.TooManyControllers;
        self.controllers[self.count] = .{ .id = id, .numa_node = numa_node, .capacity_bytes = capacity_bytes };
        self.count += 1;
    }

    pub fn find(self: *const Self, id: MemoryControllerId) MemoryControllerError!MemoryController {
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.controllers[i].id == id) return self.controllers[i];
        }
        return MemoryControllerError.NotFound;
    }

    /// Total capacity, in bytes, across every memory controller
    /// attached to `numa_node`.
    pub fn capacityForNode(self: *const Self, numa_node: ids.NumaNodeId) usize {
        var total: usize = 0;
        var i: usize = 0;
        while (i < self.count) : (i += 1) {
            if (self.controllers[i].numa_node == numa_node) total += self.controllers[i].capacity_bytes;
        }
        return total;
    }

    pub fn len(self: *const Self) usize {
        return self.count;
    }
};

const testing = @import("std").testing;

test "MemoryControllerTable adds and finds controllers" {
    var table = MemoryControllerTable.init();
    try table.add(0, 0, 8 * 1024 * 1024 * 1024);
    try table.add(1, 1, 8 * 1024 * 1024 * 1024);

    const found = try table.find(1);
    try testing.expectEqual(@as(ids.NumaNodeId, 1), found.numa_node);
    try testing.expectEqual(@as(usize, 2), table.len());
}

test "MemoryControllerTable sums capacity per NUMA node" {
    var table = MemoryControllerTable.init();
    try table.add(0, 0, 4 * 1024 * 1024 * 1024);
    try table.add(1, 0, 4 * 1024 * 1024 * 1024);
    try table.add(2, 1, 16 * 1024 * 1024 * 1024);

    try testing.expectEqual(@as(usize, 8 * 1024 * 1024 * 1024), table.capacityForNode(0));
    try testing.expectEqual(@as(usize, 16 * 1024 * 1024 * 1024), table.capacityForNode(1));
}

test "MemoryControllerTable.find reports NotFound for unknown id" {
    var table = MemoryControllerTable.init();
    try table.add(0, 0, 1024);
    try testing.expectError(MemoryControllerError.NotFound, table.find(99));
}
