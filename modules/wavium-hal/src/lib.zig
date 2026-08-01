const std = @import("std");

pub const DeviceKind = @import("device_kind.zig").DeviceKind;

pub const DiscoveryMethod = @import("discovery.zig").DiscoveryMethod;
pub const DiscoveryError = @import("discovery.zig").DiscoveryError;
pub const DeviceDescriptor = @import("discovery.zig").DeviceDescriptor;
pub const DeviceInventory = @import("discovery.zig").DeviceInventory;
pub const discoverDevices = @import("discovery.zig").discoverDevices;
pub const MAX_DEVICES = @import("discovery.zig").MAX_DEVICES;

pub const DriverError = @import("hal.zig").DriverError;
pub const DriverInitFn = @import("hal.zig").DriverInitFn;
pub const DriverRegistry = @import("hal.zig").DriverRegistry;
pub const InitReport = @import("hal.zig").InitReport;
pub const initAllDevices = @import("hal.zig").initAllDevices;
pub const initDevice = @import("hal.zig").initDevice;
pub const MAX_DRIVERS = @import("hal.zig").MAX_DRIVERS;

pub const DriverState = @import("driver.zig").DriverState;
pub const LifecycleError = @import("driver.zig").LifecycleError;
pub const ProbeFn = @import("driver.zig").ProbeFn;
pub const AttachFn = @import("driver.zig").AttachFn;
pub const DetachFn = @import("driver.zig").DetachFn;
pub const DriverLifecycle = @import("driver.zig").DriverLifecycle;
pub const AttachedDevice = @import("driver.zig").AttachedDevice;
pub const DriverManager = @import("driver.zig").DriverManager;
pub const ProbeReport = @import("driver.zig").ProbeReport;
pub const MAX_LIFECYCLE_DRIVERS = @import("driver.zig").MAX_LIFECYCLE_DRIVERS;
pub const MAX_ATTACHED_DEVICES = @import("driver.zig").MAX_ATTACHED_DEVICES;

test "device kind enum" {
    try std.testing.expectEqual(DeviceKind.cpu, DeviceKind.cpu);
}

test "discoverDevices builds inventory and rejects invalid base address" {
    const descriptors = [_]DeviceDescriptor{
        .{ .id = 1, .kind = .cpu, .base_address = 0xFEE00000, .irq = null, .discovered_via = .acpi },
        .{ .id = 2, .kind = .network, .base_address = 0xE0000000, .irq = 11, .discovered_via = .device_tree },
    };

    var inventory = try discoverDevices(descriptors[0..]);
    try std.testing.expectEqual(@as(usize, 2), inventory.count);
    try std.testing.expectEqual(@as(usize, 1), inventory.countByKind(.cpu));
    try std.testing.expect(inventory.findById(2) != null);
    try std.testing.expect(inventory.findById(99) == null);

    const bad = [_]DeviceDescriptor{
        .{ .id = 3, .kind = .storage, .base_address = 0, .irq = null, .discovered_via = .static_table },
    };
    try std.testing.expectError(DiscoveryError.InvalidBaseAddress, discoverDevices(bad[0..]));
}

test "DeviceInventory rejects duplicate ids and enforces capacity" {
    var inventory = DeviceInventory.init();
    try inventory.add(.{ .id = 1, .kind = .cpu, .base_address = 0x1000, .irq = null, .discovered_via = .static_table });
    try std.testing.expectError(DiscoveryError.DuplicateDeviceId, inventory.add(.{ .id = 1, .kind = .cpu, .base_address = 0x2000, .irq = null, .discovered_via = .static_table }));
}

var hal_test_cpu_init_calls: u32 = 0;
var hal_test_network_init_calls: u32 = 0;

fn halTestCpuInit(_: DeviceDescriptor) DriverError!void {
    hal_test_cpu_init_calls += 1;
}

fn halTestNetworkInit(_: DeviceDescriptor) DriverError!void {
    hal_test_network_init_calls += 1;
}

test "DriverRegistry rejects duplicate registration for the same kind" {
    var registry = DriverRegistry.init();
    try registry.register(.cpu, halTestCpuInit);
    try std.testing.expectError(DriverError.AlreadyRegistered, registry.register(.cpu, halTestCpuInit));
}

test "initAllDevices dispatches to registered drivers and skips unregistered kinds" {
    hal_test_cpu_init_calls = 0;
    hal_test_network_init_calls = 0;

    var registry = DriverRegistry.init();
    try registry.register(.cpu, halTestCpuInit);
    try registry.register(.network, halTestNetworkInit);

    const descriptors = [_]DeviceDescriptor{
        .{ .id = 1, .kind = .cpu, .base_address = 0xFEE00000, .irq = null, .discovered_via = .acpi },
        .{ .id = 2, .kind = .network, .base_address = 0xE0000000, .irq = 11, .discovered_via = .device_tree },
        .{ .id = 3, .kind = .storage, .base_address = 0x40000000, .irq = null, .discovered_via = .static_table },
    };
    const inventory = try discoverDevices(descriptors[0..]);

    const report = try initAllDevices(registry, inventory);
    try std.testing.expectEqual(@as(usize, 2), report.initialized);
    try std.testing.expectEqual(@as(usize, 1), report.skipped);
    try std.testing.expectEqual(@as(u32, 1), hal_test_cpu_init_calls);
    try std.testing.expectEqual(@as(u32, 1), hal_test_network_init_calls);
}

test "initDevice initializes a single device by id" {
    hal_test_cpu_init_calls = 0;

    var registry = DriverRegistry.init();
    try registry.register(.cpu, halTestCpuInit);

    const descriptors = [_]DeviceDescriptor{
        .{ .id = 7, .kind = .cpu, .base_address = 0xFEE00000, .irq = null, .discovered_via = .acpi },
    };
    const inventory = try discoverDevices(descriptors[0..]);

    try initDevice(registry, inventory, 7);
    try std.testing.expectEqual(@as(u32, 1), hal_test_cpu_init_calls);
    try std.testing.expectError(DriverError.DriverNotFound, initDevice(registry, inventory, 999));
}

var driver_test_attach_calls: u32 = 0;
var driver_test_detach_calls: u32 = 0;
var driver_test_instance: u32 = 0;

fn driverTestProbeAlwaysOk(_: DeviceDescriptor) bool {
    return true;
}

fn driverTestProbeRejectStorage(device: DeviceDescriptor) bool {
    return device.kind != .storage;
}

fn driverTestAttach(_: DeviceDescriptor) LifecycleError!*anyopaque {
    driver_test_attach_calls += 1;
    return @ptrCast(&driver_test_instance);
}

fn driverTestDetach(_: *anyopaque) void {
    driver_test_detach_calls += 1;
}

test "DriverManager registerDriver rejects duplicate kind" {
    var manager = DriverManager.init();
    const lifecycle = DriverLifecycle{ .probe = driverTestProbeAlwaysOk, .attach = driverTestAttach, .detach = driverTestDetach };
    try manager.registerDriver(.cpu, lifecycle);
    try std.testing.expectError(LifecycleError.AlreadyRegistered, manager.registerDriver(.cpu, lifecycle));
}

test "probeAndAttachAll attaches probed devices and counts skips/probe failures" {
    driver_test_attach_calls = 0;
    driver_test_detach_calls = 0;

    var manager = DriverManager.init();
    try manager.registerDriver(.cpu, .{ .probe = driverTestProbeAlwaysOk, .attach = driverTestAttach, .detach = driverTestDetach });
    try manager.registerDriver(.storage, .{ .probe = driverTestProbeRejectStorage, .attach = driverTestAttach, .detach = driverTestDetach });

    const descriptors = [_]DeviceDescriptor{
        .{ .id = 1, .kind = .cpu, .base_address = 0xFEE00000, .irq = null, .discovered_via = .acpi },
        .{ .id = 2, .kind = .storage, .base_address = 0x40000000, .irq = null, .discovered_via = .static_table },
        .{ .id = 3, .kind = .network, .base_address = 0xE0000000, .irq = 11, .discovered_via = .device_tree },
    };
    const inventory = try discoverDevices(descriptors[0..]);

    const report = try manager.probeAndAttachAll(inventory);
    try std.testing.expectEqual(@as(usize, 1), report.attached);
    try std.testing.expectEqual(@as(usize, 1), report.probe_failed);
    try std.testing.expectEqual(@as(usize, 1), report.skipped_no_driver);
    try std.testing.expectEqual(@as(u32, 1), driver_test_attach_calls);
    try std.testing.expect(manager.getAttached(1) != null);
    try std.testing.expect(manager.getAttached(2) == null);
}

test "detachDevice invokes detach and clears attached lookup" {
    driver_test_attach_calls = 0;
    driver_test_detach_calls = 0;

    var manager = DriverManager.init();
    try manager.registerDriver(.cpu, .{ .probe = driverTestProbeAlwaysOk, .attach = driverTestAttach, .detach = driverTestDetach });

    const descriptors = [_]DeviceDescriptor{
        .{ .id = 5, .kind = .cpu, .base_address = 0xFEE00000, .irq = null, .discovered_via = .acpi },
    };
    const inventory = try discoverDevices(descriptors[0..]);
    _ = try manager.probeAndAttachAll(inventory);
    try std.testing.expect(manager.getAttached(5) != null);

    try manager.detachDevice(5);
    try std.testing.expectEqual(@as(u32, 1), driver_test_detach_calls);
    try std.testing.expect(manager.getAttached(5) == null);
    try std.testing.expectError(LifecycleError.NotAttached, manager.detachDevice(5));
}
