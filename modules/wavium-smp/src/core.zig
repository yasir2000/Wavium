const std = @import("std");

pub const CoreId = u16;

pub const CoreState = enum(u8) {
    offline,
    starting,
    online,
    halted,
};

pub const CoreInfo = struct {
    id: CoreId,
    state: CoreState,
    is_bootstrap: bool,
};

pub const CoreError = error{
    CoreNotFound,
    InvalidTransition,
    RegistryFull,
};

pub const max_cores: usize = 256;

/// Runtime-managed registry of every logical core the SMP framework knows
/// about. There is no kernel involved: the runtime itself owns core
/// lifecycle state (offline/starting/online/halted), which is the basis for
/// CPU hotplug support (a core can be taken `.halted` and later transitioned
/// back to `.offline` for a future `.starting` retry).
pub const CoreRegistry = struct {
    cores: [max_cores]CoreInfo,
    count: usize,

    pub fn init() CoreRegistry {
        return .{ .cores = undefined, .count = 0 };
    }

    pub fn register(self: *CoreRegistry, id: CoreId, is_bootstrap: bool) CoreError!void {
        if (self.count >= max_cores) return error.RegistryFull;
        self.cores[self.count] = .{ .id = id, .state = .offline, .is_bootstrap = is_bootstrap };
        self.count += 1;
    }

    pub fn find(self: *CoreRegistry, id: CoreId) ?*CoreInfo {
        for (self.cores[0..self.count]) |*c| {
            if (c.id == id) return c;
        }
        return null;
    }

    /// Enforces the core lifecycle state machine:
    /// offline -> starting -> online -> halted -> offline (hotplug retry).
    pub fn setState(self: *CoreRegistry, id: CoreId, new_state: CoreState) CoreError!void {
        const info = self.find(id) orelse return error.CoreNotFound;
        try validateTransition(info.state, new_state);
        info.state = new_state;
    }

    pub fn onlineCount(self: *CoreRegistry) usize {
        var n: usize = 0;
        for (self.cores[0..self.count]) |c| {
            if (c.state == .online) n += 1;
        }
        return n;
    }
};

fn validateTransition(from: CoreState, to: CoreState) CoreError!void {
    const ok = switch (from) {
        .offline => to == .starting,
        .starting => to == .online or to == .offline,
        .online => to == .halted or to == .offline,
        .halted => to == .offline,
    };
    if (!ok) return error.InvalidTransition;
}

test "register and find core" {
    var reg = CoreRegistry.init();
    try reg.register(0, true);
    try reg.register(1, false);

    const bsp = reg.find(0) orelse unreachable;
    try std.testing.expect(bsp.is_bootstrap);
    try std.testing.expectEqual(CoreState.offline, bsp.state);
    try std.testing.expect(reg.find(99) == null);
}

test "state machine allows valid transitions and rejects invalid ones" {
    var reg = CoreRegistry.init();
    try reg.register(0, true);

    try reg.setState(0, .starting);
    try reg.setState(0, .online);
    try std.testing.expectEqual(@as(usize, 1), reg.onlineCount());

    try std.testing.expectError(error.InvalidTransition, reg.setState(0, .starting));

    try reg.setState(0, .halted);
    try std.testing.expectEqual(@as(usize, 0), reg.onlineCount());

    // hotplug: halted core can go back offline and be retried
    try reg.setState(0, .offline);
    try reg.setState(0, .starting);
}

test "setState on unknown core returns CoreNotFound" {
    var reg = CoreRegistry.init();
    try std.testing.expectError(error.CoreNotFound, reg.setState(5, .starting));
}

test "registry rejects registration past max_cores" {
    var reg = CoreRegistry.init();
    var i: usize = 0;
    while (i < max_cores) : (i += 1) {
        try reg.register(@intCast(i), i == 0);
    }
    try std.testing.expectError(error.RegistryFull, reg.register(@intCast(max_cores), false));
}
