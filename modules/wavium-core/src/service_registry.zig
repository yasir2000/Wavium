const std = @import("std");

pub const ServiceRegistry = struct {
    allocator: std.mem.Allocator,
    entries: std.StringHashMap(*anyopaque),

    pub fn init(allocator: std.mem.Allocator) ServiceRegistry {
        return .{
            .allocator = allocator,
            .entries = std.StringHashMap(*anyopaque).init(allocator),
        };
    }

    pub fn deinit(self: *ServiceRegistry) void {
        self.entries.deinit();
    }

    pub fn register(self: *ServiceRegistry, name: []const u8, service: *anyopaque) !void {
        try self.entries.put(name, service);
    }

    pub fn lookup(self: *ServiceRegistry, name: []const u8) ?*anyopaque {
        return self.entries.get(name);
    }
};
