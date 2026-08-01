const std = @import("std");

/// Wavium hardware target package: the `.wboard` format describes a board's
/// CPU, memory, devices, driver bindings, and required capabilities so that
/// `wavium build`/`wavium deploy` can target a specific piece of hardware.
pub fn moduleName() []const u8 {
    return "wavium-board";
}

pub const CpuArch = enum(u8) {
    x86_64,
    aarch64,
    riscv64,
};

pub const CpuDescriptor = struct {
    arch: CpuArch,
    core_count: u32,
    clock_mhz: u32,
};

pub const MemoryDescriptor = struct {
    total_bytes: u64,
};

pub const DriverBinding = struct {
    device_name: []const u8,
    driver_name: []const u8,
};

pub const BoardDescriptor = struct {
    name: []const u8,
    cpu: CpuDescriptor,
    memory: MemoryDescriptor,
    devices: []const []const u8,
    drivers: []const DriverBinding,
    capabilities: []const []const u8,
};

pub const BoardError = error{
    InvalidBoardName,
    InvalidArch,
    InvalidCoreCount,
    InvalidClock,
    InvalidMemory,
    InvalidDeviceName,
    UnknownDriverDevice,
    InvalidDriverName,
    InvalidCapability,
    MissingField,
    MalformedDriverBinding,
    BufferTooSmall,
};

/// Validates structural and referential integrity of a board descriptor:
/// every driver binding must reference a device that is actually declared,
/// and no required field may be left empty/zero.
pub fn validateBoard(board: BoardDescriptor) BoardError!void {
    if (board.name.len == 0) return error.InvalidBoardName;
    if (board.cpu.core_count == 0) return error.InvalidCoreCount;
    if (board.cpu.clock_mhz == 0) return error.InvalidClock;
    if (board.memory.total_bytes == 0) return error.InvalidMemory;

    for (board.devices) |device_name| {
        if (device_name.len == 0) return error.InvalidDeviceName;
    }

    for (board.drivers) |binding| {
        if (binding.driver_name.len == 0) return error.InvalidDriverName;

        var found = false;
        for (board.devices) |device_name| {
            if (std.mem.eql(u8, device_name, binding.device_name)) {
                found = true;
                break;
            }
        }
        if (!found) return error.UnknownDriverDevice;
    }

    for (board.capabilities) |cap| {
        if (cap.len == 0) return error.InvalidCapability;
    }
}

pub fn archName(arch: CpuArch) []const u8 {
    return switch (arch) {
        .x86_64 => "x86_64",
        .aarch64 => "aarch64",
        .riscv64 => "riscv64",
    };
}

fn parseArchName(name: []const u8) BoardError!CpuArch {
    if (std.mem.eql(u8, name, "x86_64")) return .x86_64;
    if (std.mem.eql(u8, name, "aarch64")) return .aarch64;
    if (std.mem.eql(u8, name, "riscv64")) return .riscv64;
    return error.InvalidArch;
}

pub const ParsedBoard = struct {
    board: BoardDescriptor,
    device_count: usize,
    driver_count: usize,
    capability_count: usize,
};

/// Parses the line-based `key=value` `.wboard` text format. `devices_out`,
/// `drivers_out` and `capabilities_out` are caller-provided scratch slices
/// (no allocator dependency, matching wavium-build's manifest parser style).
pub fn parseBoard(
    input: []const u8,
    devices_out: [][]const u8,
    drivers_out: []DriverBinding,
    capabilities_out: [][]const u8,
) !ParsedBoard {
    var name: []const u8 = "";
    var arch: CpuArch = .x86_64;
    var core_count: u32 = 0;
    var clock_mhz: u32 = 0;
    var memory_bytes: u64 = 0;
    var device_count: usize = 0;
    var driver_count: usize = 0;
    var capability_count: usize = 0;

    var lines = std.mem.splitScalar(u8, input, '\n');
    while (lines.next()) |raw_line| {
        const line = std.mem.trim(u8, raw_line, " \r\t");
        if (line.len == 0) continue;

        var kv = std.mem.splitScalar(u8, line, '=');
        const key = kv.next() orelse continue;
        const val = kv.next() orelse continue;

        if (std.mem.eql(u8, key, "name")) {
            name = val;
        } else if (std.mem.eql(u8, key, "arch")) {
            arch = try parseArchName(val);
        } else if (std.mem.eql(u8, key, "cores")) {
            core_count = try std.fmt.parseUnsigned(u32, val, 10);
        } else if (std.mem.eql(u8, key, "clock_mhz")) {
            clock_mhz = try std.fmt.parseUnsigned(u32, val, 10);
        } else if (std.mem.eql(u8, key, "memory_bytes")) {
            memory_bytes = try std.fmt.parseUnsigned(u64, val, 10);
        } else if (std.mem.eql(u8, key, "devices")) {
            device_count = try splitCsv(val, devices_out);
        } else if (std.mem.eql(u8, key, "drivers")) {
            driver_count = try splitDriverCsv(val, drivers_out);
        } else if (std.mem.eql(u8, key, "capabilities")) {
            capability_count = try splitCsv(val, capabilities_out);
        }
    }

    const board = BoardDescriptor{
        .name = name,
        .cpu = .{ .arch = arch, .core_count = core_count, .clock_mhz = clock_mhz },
        .memory = .{ .total_bytes = memory_bytes },
        .devices = devices_out[0..device_count],
        .drivers = drivers_out[0..driver_count],
        .capabilities = capabilities_out[0..capability_count],
    };
    try validateBoard(board);

    return .{
        .board = board,
        .device_count = device_count,
        .driver_count = driver_count,
        .capability_count = capability_count,
    };
}

fn splitCsv(value: []const u8, out: [][]const u8) !usize {
    if (value.len == 0) return 0;

    var n: usize = 0;
    var parts = std.mem.splitScalar(u8, value, ',');
    while (parts.next()) |p| {
        if (p.len == 0) continue;
        if (n >= out.len) return error.BufferTooSmall;
        out[n] = p;
        n += 1;
    }
    return n;
}

fn splitDriverCsv(value: []const u8, out: []DriverBinding) !usize {
    if (value.len == 0) return 0;

    var n: usize = 0;
    var parts = std.mem.splitScalar(u8, value, ',');
    while (parts.next()) |p| {
        if (p.len == 0) continue;
        if (n >= out.len) return error.BufferTooSmall;

        var pair = std.mem.splitScalar(u8, p, ':');
        const device_name = pair.next() orelse return error.MalformedDriverBinding;
        const driver_name = pair.next() orelse return error.MalformedDriverBinding;

        out[n] = .{ .device_name = device_name, .driver_name = driver_name };
        n += 1;
    }
    return n;
}

const raspberry_pi_wboard = @embedFile("boards/raspberry-pi.wboard");
const server_x86_wboard = @embedFile("boards/server-x86.wboard");
const riscv_board_wboard = @embedFile("boards/riscv-board.wboard");

test "module name" {
    try std.testing.expectEqualStrings("wavium-board", moduleName());
}

test "validateBoard accepts a well-formed descriptor" {
    const devices = [_][]const u8{"uart0"};
    const drivers = [_]DriverBinding{.{ .device_name = "uart0", .driver_name = "pl011-driver" }};
    const caps = [_][]const u8{"storage.read"};

    const board = BoardDescriptor{
        .name = "test-board",
        .cpu = .{ .arch = .aarch64, .core_count = 4, .clock_mhz = 1500 },
        .memory = .{ .total_bytes = 1024 },
        .devices = devices[0..],
        .drivers = drivers[0..],
        .capabilities = caps[0..],
    };
    try validateBoard(board);
}

test "validateBoard rejects driver binding for undeclared device" {
    const drivers = [_]DriverBinding{.{ .device_name = "missing-device", .driver_name = "some-driver" }};
    const board = BoardDescriptor{
        .name = "test-board",
        .cpu = .{ .arch = .x86_64, .core_count = 1, .clock_mhz = 100 },
        .memory = .{ .total_bytes = 1024 },
        .devices = &.{},
        .drivers = drivers[0..],
        .capabilities = &.{},
    };
    try std.testing.expectError(error.UnknownDriverDevice, validateBoard(board));
}

test "validateBoard rejects zero core count and zero memory" {
    const zero_cores = BoardDescriptor{
        .name = "b",
        .cpu = .{ .arch = .x86_64, .core_count = 0, .clock_mhz = 100 },
        .memory = .{ .total_bytes = 1024 },
        .devices = &.{},
        .drivers = &.{},
        .capabilities = &.{},
    };
    try std.testing.expectError(error.InvalidCoreCount, validateBoard(zero_cores));

    const zero_memory = BoardDescriptor{
        .name = "b",
        .cpu = .{ .arch = .x86_64, .core_count = 1, .clock_mhz = 100 },
        .memory = .{ .total_bytes = 0 },
        .devices = &.{},
        .drivers = &.{},
        .capabilities = &.{},
    };
    try std.testing.expectError(error.InvalidMemory, validateBoard(zero_memory));
}

test "parseBoard parses raspberry-pi.wboard" {
    var devices: [8][]const u8 = undefined;
    var drivers: [8]DriverBinding = undefined;
    var caps: [8][]const u8 = undefined;

    const parsed = try parseBoard(raspberry_pi_wboard, devices[0..], drivers[0..], caps[0..]);
    try std.testing.expectEqualStrings("raspberry-pi", parsed.board.name);
    try std.testing.expectEqual(CpuArch.aarch64, parsed.board.cpu.arch);
    try std.testing.expect(parsed.device_count > 0);
    try std.testing.expect(parsed.driver_count > 0);
    try std.testing.expect(parsed.capability_count > 0);
}

test "parseBoard parses server-x86.wboard" {
    var devices: [8][]const u8 = undefined;
    var drivers: [8]DriverBinding = undefined;
    var caps: [8][]const u8 = undefined;

    const parsed = try parseBoard(server_x86_wboard, devices[0..], drivers[0..], caps[0..]);
    try std.testing.expectEqualStrings("server-x86", parsed.board.name);
    try std.testing.expectEqual(CpuArch.x86_64, parsed.board.cpu.arch);
}

test "parseBoard parses riscv-board.wboard" {
    var devices: [8][]const u8 = undefined;
    var drivers: [8]DriverBinding = undefined;
    var caps: [8][]const u8 = undefined;

    const parsed = try parseBoard(riscv_board_wboard, devices[0..], drivers[0..], caps[0..]);
    try std.testing.expectEqualStrings("riscv-board", parsed.board.name);
    try std.testing.expectEqual(CpuArch.riscv64, parsed.board.cpu.arch);
}

test "parseBoard rejects malformed driver binding" {
    var devices: [4][]const u8 = undefined;
    var drivers: [4]DriverBinding = undefined;
    var caps: [4][]const u8 = undefined;

    const bad_input =
        "name=bad\narch=x86_64\ncores=1\nclock_mhz=100\nmemory_bytes=1024\ndevices=uart0\ndrivers=uart0-no-colon\ncapabilities=storage.read\n";
    try std.testing.expectError(error.MalformedDriverBinding, parseBoard(bad_input, devices[0..], drivers[0..], caps[0..]));
}
