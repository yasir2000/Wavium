const discovery = @import("discovery.zig");
pub const DeviceDescriptor = discovery.DeviceDescriptor;
pub const DeviceInventory = discovery.DeviceInventory;
const device_kind = @import("device_kind.zig");
pub const DeviceKind = device_kind.DeviceKind;

/// Unified hardware abstraction layer core. Runtime code calls
/// `hal.initAllDevices(inventory)` / `hal.getDevice(id)` without knowing
/// which concrete driver backs a given device kind; drivers register
/// themselves against a `DeviceKind` once during startup.
pub const DriverError = error{
    AlreadyRegistered,
    RegistryFull,
    DriverNotFound,
    InitFailed,
};

pub const DriverInitFn = *const fn (device: DeviceDescriptor) DriverError!void;

pub const MAX_DRIVERS: usize = 32;

const DriverEntry = struct {
    kind: DeviceKind,
    init_fn: DriverInitFn,
};

pub const DriverRegistry = struct {
    entries: [MAX_DRIVERS]DriverEntry,
    count: usize,

    pub fn init() DriverRegistry {
        return .{ .entries = undefined, .count = 0 };
    }

    pub fn register(self: *DriverRegistry, kind: DeviceKind, init_fn: DriverInitFn) DriverError!void {
        for (self.entries[0..self.count]) |entry| {
            if (entry.kind == kind) {
                return error.AlreadyRegistered;
            }
        }
        if (self.count >= MAX_DRIVERS) {
            return error.RegistryFull;
        }
        self.entries[self.count] = .{ .kind = kind, .init_fn = init_fn };
        self.count += 1;
    }

    fn findDriver(self: DriverRegistry, kind: DeviceKind) DriverError!DriverInitFn {
        for (self.entries[0..self.count]) |entry| {
            if (entry.kind == kind) return entry.init_fn;
        }
        return error.DriverNotFound;
    }
};

pub const InitReport = struct {
    initialized: usize,
    skipped: usize,
};

/// Initializes every device in `inventory` using whichever driver is
/// registered for its `DeviceKind`. Devices whose kind has no registered
/// driver are skipped (counted, not treated as a hard failure), since a
/// partial device inventory is expected on real hardware.
pub fn initAllDevices(registry: DriverRegistry, inventory: DeviceInventory) DriverError!InitReport {
    var report = InitReport{ .initialized = 0, .skipped = 0 };
    for (inventory.devices[0..inventory.count]) |device| {
        const init_fn = registry.findDriver(device.kind) catch {
            report.skipped += 1;
            continue;
        };
        try init_fn(device);
        report.initialized += 1;
    }
    return report;
}

/// Looks up a single device by id and initializes it via its registered
/// driver (`hal.getDevice(id)` + init in one call).
pub fn initDevice(registry: DriverRegistry, inventory: DeviceInventory, id: u32) DriverError!void {
    const device = inventory.findById(id) orelse return error.DriverNotFound;
    const init_fn = try registry.findDriver(device.kind);
    try init_fn(device);
}
