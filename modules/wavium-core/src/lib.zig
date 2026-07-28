const std = @import("std");

pub const RuntimeConfig = @import("config.zig").RuntimeConfig;
pub const RuntimeContext = @import("runtime_context.zig").RuntimeContext;
pub const RuntimeState = @import("lifecycle.zig").RuntimeState;
pub const ServiceRegistry = @import("service_registry.zig").ServiceRegistry;

test "runtime context lifecycle" {
    var ctx = try RuntimeContext.init(std.testing.allocator, .{});
    try std.testing.expectEqual(RuntimeState.initialized, ctx.state);

    try ctx.start();
    try std.testing.expectEqual(RuntimeState.running, ctx.state);

    ctx.shutdown();
    try std.testing.expectEqual(RuntimeState.stopped, ctx.state);
}

test "service registry roundtrip" {
    var ctx = try RuntimeContext.init(std.testing.allocator, .{});
    defer ctx.shutdown();

    var value: u32 = 42;
    try ctx.services.register("demo", @ptrCast(&value));

    const found = ctx.services.lookup("demo");
    try std.testing.expect(found != null);
}
