const discovery = @import("discovery.zig");
pub const DeviceDescriptor = discovery.DeviceDescriptor;
pub const DeviceInventory = discovery.DeviceInventory;
const device_kind = @import("device_kind.zig");
pub const DeviceKind = device_kind.DeviceKind;

/// Full driver lifecycle framework: probe -> attach -> detach. This builds
/// on top of `hal.zig`'s simple init-dispatch registry by adding
/// compatibility probing and stateful attach/detach so drivers can hold a
/// per-device instance (e.g. a mapped MMIO context) across their lifetime,
/// without the runtime ever branching on device kind directly.
pub const DriverState = enum {
    probed,
    attached,
    detached,
    probe_failed,
};

pub const LifecycleError = error{
    AlreadyRegistered,
    RegistryFull,
    DriverNotFound,
    AttachTableFull,
    AlreadyAttached,
    NotAttached,
    AttachFailed,
};

pub const ProbeFn = *const fn (device: DeviceDescriptor) bool;
pub const AttachFn = *const fn (device: DeviceDescriptor) LifecycleError!*anyopaque;
pub const DetachFn = *const fn (instance: *anyopaque) void;

pub const DriverLifecycle = struct {
    probe: ProbeFn,
    attach: AttachFn,
    detach: DetachFn,
};

const LifecycleEntry = struct {
    kind: DeviceKind,
    lifecycle: DriverLifecycle,
};

pub const AttachedDevice = struct {
    device_id: u32,
    kind: DeviceKind,
    instance: *anyopaque,
    state: DriverState,
};

pub const MAX_LIFECYCLE_DRIVERS: usize = 32;
pub const MAX_ATTACHED_DEVICES: usize = 64;

pub const ProbeReport = struct {
    attached: usize,
    probe_failed: usize,
    skipped_no_driver: usize,
};

pub const DriverManager = struct {
    drivers: [MAX_LIFECYCLE_DRIVERS]LifecycleEntry,
    driver_count: usize,
    attached: [MAX_ATTACHED_DEVICES]AttachedDevice,
    attached_count: usize,

    pub fn init() DriverManager {
        return .{
            .drivers = undefined,
            .driver_count = 0,
            .attached = undefined,
            .attached_count = 0,
        };
    }

    pub fn registerDriver(self: *DriverManager, kind: DeviceKind, lifecycle: DriverLifecycle) LifecycleError!void {
        for (self.drivers[0..self.driver_count]) |entry| {
            if (entry.kind == kind) {
                return error.AlreadyRegistered;
            }
        }
        if (self.driver_count >= MAX_LIFECYCLE_DRIVERS) {
            return error.RegistryFull;
        }
        self.drivers[self.driver_count] = .{ .kind = kind, .lifecycle = lifecycle };
        self.driver_count += 1;
    }

    fn findLifecycle(self: DriverManager, kind: DeviceKind) LifecycleError!DriverLifecycle {
        for (self.drivers[0..self.driver_count]) |entry| {
            if (entry.kind == kind) return entry.lifecycle;
        }
        return error.DriverNotFound;
    }

    fn isAttached(self: DriverManager, device_id: u32) bool {
        for (self.attached[0..self.attached_count]) |a| {
            if (a.device_id == device_id and a.state == .attached) return true;
        }
        return false;
    }

    /// Probes and attaches every device in `inventory` whose kind has a
    /// registered driver and whose `probe()` succeeds. Devices with no
    /// registered driver are skipped; devices that fail probing are
    /// counted but not treated as a hard error (matches real hardware
    /// enumeration where not every discovered device is populated/wired).
    pub fn probeAndAttachAll(self: *DriverManager, inventory: DeviceInventory) LifecycleError!ProbeReport {
        var report = ProbeReport{ .attached = 0, .probe_failed = 0, .skipped_no_driver = 0 };
        for (inventory.devices[0..inventory.count]) |device| {
            const lifecycle = self.findLifecycle(device.kind) catch {
                report.skipped_no_driver += 1;
                continue;
            };
            if (!lifecycle.probe(device)) {
                report.probe_failed += 1;
                continue;
            }
            try self.attachDevice(device, lifecycle);
            report.attached += 1;
        }
        return report;
    }

    fn attachDevice(self: *DriverManager, device: DeviceDescriptor, lifecycle: DriverLifecycle) LifecycleError!void {
        if (self.isAttached(device.id)) {
            return error.AlreadyAttached;
        }
        if (self.attached_count >= MAX_ATTACHED_DEVICES) {
            return error.AttachTableFull;
        }
        const instance = try lifecycle.attach(device);
        self.attached[self.attached_count] = .{
            .device_id = device.id,
            .kind = device.kind,
            .instance = instance,
            .state = .attached,
        };
        self.attached_count += 1;
    }

    pub fn getAttached(self: DriverManager, device_id: u32) ?AttachedDevice {
        for (self.attached[0..self.attached_count]) |a| {
            if (a.device_id == device_id and a.state == .attached) return a;
        }
        return null;
    }

    /// Detaches a previously attached device, invoking its driver's
    /// `detach()` and marking the slot `.detached` (kept for audit rather
    /// than compacted out of the fixed array).
    pub fn detachDevice(self: *DriverManager, device_id: u32) LifecycleError!void {
        for (self.attached[0..self.attached_count]) |*a| {
            if (a.device_id == device_id and a.state == .attached) {
                const lifecycle = try self.findLifecycle(a.kind);
                lifecycle.detach(a.instance);
                a.state = .detached;
                return;
            }
        }
        return error.NotAttached;
    }
};
