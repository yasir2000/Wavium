const std = @import("std");
const cfg = @import("config.zig");
const lifecycle = @import("lifecycle.zig");
const registry = @import("service_registry.zig");

pub const RuntimeContext = struct {
    allocator: std.mem.Allocator,
    config: cfg.RuntimeConfig,
    state: lifecycle.RuntimeState,
    services: registry.ServiceRegistry,

    pub fn init(allocator: std.mem.Allocator, config: cfg.RuntimeConfig) !RuntimeContext {
        try cfg.validate(config);
        return .{
            .allocator = allocator,
            .config = config,
            .state = .initialized,
            .services = registry.ServiceRegistry.init(allocator),
        };
    }

    pub fn start(self: *RuntimeContext) !void {
        if (self.state != .initialized) return error.InvalidStateTransition;
        self.state = .running;
    }

    pub fn shutdown(self: *RuntimeContext) void {
        if (self.state == .running or self.state == .initialized) {
            self.state = .stopped;
        }
        self.services.deinit();
    }
};
