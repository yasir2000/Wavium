const std = @import("std");

const arch_id = @import("arch_id.zig");

pub const Arch = arch_id.Arch;
pub const ArchError = arch_id.ArchError;
pub const currentArch = arch_id.current;

pub const cpu = @import("cpu.zig");
pub const interrupts = @import("interrupts.zig");
pub const timers = @import("timers.zig");
pub const mmu = @import("mmu.zig");
pub const registers = @import("registers.zig");
pub const atomic = @import("atomic.zig");
pub const context = @import("context.zig");

test "currentArch resolves supported host architectures" {
    const builtin_arch = @import("builtin").cpu.arch;
    if (builtin_arch == .x86_64 or builtin_arch == .aarch64 or builtin_arch == .riscv64) {
        _ = try currentArch();
    } else {
        try std.testing.expectError(ArchError.UnsupportedArchitecture, currentArch());
    }
}

test "cpu.init reports architecture features" {
    const state = cpu.init(.aarch64);
    try std.testing.expectEqual(Arch.aarch64, state.arch);
    try std.testing.expect(state.initialized);
    try std.testing.expect(state.features.supports_mmu);
}

test "interrupts.InterruptController starts masked and toggles" {
    var ic = interrupts.InterruptController.init();
    try std.testing.expect(ic.isMasked());
    ic.unmask();
    try std.testing.expect(!ic.isMasked());
    ic.mask();
    try std.testing.expect(ic.isMasked());
}

test "timers.sleep rejects zero duration" {
    try std.testing.expectError(timers.TimerError.InvalidDuration, timers.sleep(.{ .nanos = 0 }));
    try timers.sleep(.{ .nanos = 1 });
}

test "timers.nominalTicksPerSecond differs for riscv64" {
    try std.testing.expect(timers.nominalTicksPerSecond(.riscv64) != timers.nominalTicksPerSecond(.x86_64));
}

test "mmu.map validates alignment and length" {
    try mmu.map(.{
        .virtual_addr = 0x1000,
        .physical_addr = 0x2000,
        .length = mmu.PAGE_SIZE,
        .flags = .{},
    });

    try std.testing.expectError(mmu.MmuError.InvalidAlignment, mmu.map(.{
        .virtual_addr = 0x1001,
        .physical_addr = 0x2000,
        .length = mmu.PAGE_SIZE,
        .flags = .{},
    }));

    try std.testing.expectError(mmu.MmuError.InvalidLength, mmu.map(.{
        .virtual_addr = 0x1000,
        .physical_addr = 0x2000,
        .length = 0,
        .flags = .{},
    }));
}

test "registers.namesForArch returns architecture-specific names" {
    const x86_names = registers.namesForArch(.x86_64);
    try std.testing.expectEqualStrings("rsp", x86_names.stack_pointer);

    const arm_names = registers.namesForArch(.aarch64);
    try std.testing.expectEqualStrings("x30", arm_names.return_address);

    const riscv_names = registers.namesForArch(.riscv64);
    try std.testing.expectEqualStrings("ra", riscv_names.return_address);
}

test "atomic.CacheAligned enforces cache-line alignment" {
    const Aligned = atomic.CacheAligned(u32);
    const value = Aligned.init(42);
    try std.testing.expectEqual(@as(u32, 42), value.value);
    try std.testing.expectEqual(@as(usize, 0), @intFromPtr(&value.value) % atomic.CACHE_LINE_SIZE);
}

test "atomic.Counter loads, stores, and fetch-adds" {
    const Counter = atomic.Counter(u32);
    var counter = Counter.init(1);
    try std.testing.expectEqual(@as(u32, 1), counter.load());
    counter.store(10);
    try std.testing.expectEqual(@as(u32, 10), counter.load());
    const prev = counter.fetchAdd(5);
    try std.testing.expectEqual(@as(u32, 10), prev);
    try std.testing.expectEqual(@as(u32, 15), counter.load());
}

test "context.switchContext validates and applies new context" {
    var from = context.CpuContext{ .arch = .x86_64, .stack_pointer = 0x1000, .program_counter = 0x2000 };
    const to = context.CpuContext{ .arch = .x86_64, .stack_pointer = 0x3000, .program_counter = 0x4000 };
    try context.switchContext(&from, to);
    try std.testing.expectEqual(@as(u64, 0x3000), from.stack_pointer);
}

test "context.validateContext rejects zero stack pointer" {
    const bad = context.CpuContext{ .arch = .x86_64, .stack_pointer = 0, .program_counter = 0x1000 };
    try std.testing.expectError(context.ContextError.InvalidStackPointer, context.validateContext(bad));
}
