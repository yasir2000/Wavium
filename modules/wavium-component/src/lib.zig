const std = @import("std");

pub const ComponentId = u64;

pub const ComponentMetadata = struct {
    id: ComponentId,
    name: []const u8,
};

pub const ComponentPackage = struct {
    name: []const u8,
    world: []const u8,
};

pub const Component = struct {
    metadata: ComponentMetadata,
    world: []const u8,
};

pub const WorldSpec = struct {
    name: []const u8,
};

pub const LinkedComponent = struct {
    component: Component,
    world: WorldSpec,
};

pub const ComponentLoader = struct {
    next_id: ComponentId,

    pub fn init() ComponentLoader {
        return .{ .next_id = 1 };
    }

    pub fn loadComponent(self: *ComponentLoader, pkg: ComponentPackage) !Component {
        if (pkg.name.len == 0) return error.InvalidComponentName;
        if (pkg.world.len == 0) return error.InvalidComponentWorld;

        const c = Component{
            .metadata = .{ .id = self.next_id, .name = pkg.name },
            .world = pkg.world,
        };
        self.next_id += 1;
        return c;
    }

    pub fn link(_: *ComponentLoader, component: Component, world: WorldSpec) !LinkedComponent {
        if (!std.mem.eql(u8, component.world, world.name)) return error.WorldMismatch;
        return .{ .component = component, .world = world };
    }
};

test "component metadata roundtrip" {
    const meta = ComponentMetadata{ .id = 1, .name = "hello" };
    try std.testing.expectEqual(@as(ComponentId, 1), meta.id);
}

test "component load and world link" {
    var loader = ComponentLoader.init();
    const comp = try loader.loadComponent(.{ .name = "hello", .world = "runtime" });
    const linked = try loader.link(comp, .{ .name = "runtime" });

    try std.testing.expectEqual(@as(ComponentId, 1), linked.component.metadata.id);
    try std.testing.expectError(error.WorldMismatch, loader.link(comp, .{ .name = "wrong" }));
}
