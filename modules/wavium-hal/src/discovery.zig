const device_kind = @import("device_kind.zig");
pub const DeviceKind = device_kind.DeviceKind;

/// Mechanism used to discover a device. Real backends will parse ACPI
/// tables (x86_64/aarch64 ACPI-capable platforms) or a flattened device
/// tree blob (aarch64/riscv64 embedded platforms); this contract lets
/// runtime code call a single `discovery.discoverDevices()` entry point
/// without branching on firmware type.
pub const DiscoveryMethod = enum {
    acpi,
    device_tree,
    static_table,
};

pub const DiscoveryError = error{
    InventoryFull,
    DuplicateDeviceId,
    InvalidBaseAddress,
};

pub const DeviceDescriptor = struct {
    id: u32,
    kind: DeviceKind,
    base_address: u64,
    irq: ?u16,
    discovered_via: DiscoveryMethod,
};

pub const MAX_DEVICES: usize = 64;

/// Fixed-capacity device inventory (no heap dependency, matching the
/// pattern used by `boot/entry/contract.zig`'s fixed-size memory region
/// array), since discovery must be usable before a general allocator
/// exists.
pub const DeviceInventory = struct {
    devices: [MAX_DEVICES]DeviceDescriptor,
    count: usize,

    pub fn init() DeviceInventory {
        return .{ .devices = undefined, .count = 0 };
    }

    pub fn add(self: *DeviceInventory, descriptor: DeviceDescriptor) DiscoveryError!void {
        if (self.count >= MAX_DEVICES) {
            return error.InventoryFull;
        }
        for (self.devices[0..self.count]) |existing| {
            if (existing.id == descriptor.id) {
                return error.DuplicateDeviceId;
            }
        }
        self.devices[self.count] = descriptor;
        self.count += 1;
    }

    pub fn findById(self: DeviceInventory, id: u32) ?DeviceDescriptor {
        for (self.devices[0..self.count]) |d| {
            if (d.id == id) return d;
        }
        return null;
    }

    pub fn countByKind(self: DeviceInventory, kind: DeviceKind) usize {
        var total: usize = 0;
        for (self.devices[0..self.count]) |d| {
            if (d.kind == kind) total += 1;
        }
        return total;
    }
};

/// Discovers devices from a caller-supplied raw descriptor table (already
/// parsed from ACPI/DTB/static firmware tables by a lower-level backend)
/// and builds a validated inventory. Base address 0 is rejected as invalid
/// since it typically denotes an unmapped or malformed entry.
pub fn discoverDevices(raw_descriptors: []const DeviceDescriptor) DiscoveryError!DeviceInventory {
    var inventory = DeviceInventory.init();
    for (raw_descriptors) |descriptor| {
        if (descriptor.base_address == 0) {
            return error.InvalidBaseAddress;
        }
        try inventory.add(descriptor);
    }
    return inventory;
}
