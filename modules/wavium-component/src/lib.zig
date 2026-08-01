const std = @import("std");

pub const ComponentId = @import("component.zig").ComponentId;
pub const ComponentMetadata = @import("component.zig").ComponentMetadata;
pub const ComponentPackage = @import("component.zig").ComponentPackage;
pub const Component = @import("component.zig").Component;
pub const WorldSpec = @import("component.zig").WorldSpec;
pub const LinkedComponent = @import("component.zig").LinkedComponent;
pub const ComponentLoader = @import("component.zig").ComponentLoader;

pub const RuntimeError = @import("runtime.zig").RuntimeError;
pub const InstantiateFn = @import("runtime.zig").InstantiateFn;
pub const InvokeFn = @import("runtime.zig").InvokeFn;
pub const DestroyFn = @import("runtime.zig").DestroyFn;
pub const ExecutionBackend = @import("runtime.zig").ExecutionBackend;
pub const RunningComponent = @import("runtime.zig").RunningComponent;
pub const ComponentRuntime = @import("runtime.zig").ComponentRuntime;

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

var runtime_test_instantiate_calls: u32 = 0;
var runtime_test_destroy_calls: u32 = 0;
var runtime_test_instance: u32 = 0;

fn fakeInstantiate(_: LinkedComponent) RuntimeError!*anyopaque {
    runtime_test_instantiate_calls += 1;
    return @ptrCast(&runtime_test_instance);
}

fn fakeInvoke(_: *anyopaque, _: []const u8, args: []const u8) RuntimeError!usize {
    return args.len;
}

fn fakeDestroy(_: *anyopaque) void {
    runtime_test_destroy_calls += 1;
}

test "ComponentRuntime start/invoke/shutdown lifecycle" {
    runtime_test_instantiate_calls = 0;
    runtime_test_destroy_calls = 0;

    var loader = ComponentLoader.init();
    const comp = try loader.loadComponent(.{ .name = "hello-component", .world = "runtime" });
    const linked = try loader.link(comp, .{ .name = "runtime" });

    const backend = ExecutionBackend{ .instantiate = fakeInstantiate, .invoke = fakeInvoke, .destroy = fakeDestroy };
    const runtime = ComponentRuntime.init(backend);

    var running = try runtime.start(linked);
    try std.testing.expectEqual(@as(u32, 1), runtime_test_instantiate_calls);

    const bytes_returned = try running.invoke("run", "hello");
    try std.testing.expectEqual(@as(usize, 5), bytes_returned);

    running.shutdown();
    try std.testing.expectEqual(@as(u32, 1), runtime_test_destroy_calls);
    try std.testing.expectError(RuntimeError.NotInstantiated, running.invoke("run", "hello"));

    // Shutdown is idempotent - a second call must not invoke destroy again.
    running.shutdown();
    try std.testing.expectEqual(@as(u32, 1), runtime_test_destroy_calls);
}
