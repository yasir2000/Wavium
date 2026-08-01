const std = @import("std");

/// Physical memory manager: a bitmap-based physical frame allocator.
///
/// This operates purely on caller-supplied storage (the bitmap slice) so it
/// has no heap dependency and can run during early boot before a general
/// allocator exists. Physical memory regions are described independently of
/// `boot/entry/contract.zig`'s `MemoryRegion` (same shape, no cross-module
/// build dependency) so callers translate the boot handoff memory map into
/// `PhysicalMemoryRegion` values before reserving them here.
pub const PAGE_SIZE: u64 = 4096;

pub const FrameAllocError = error{
    OutOfMemory,
    InvalidBitmapSize,
    UnalignedAddress,
    OutOfRange,
    DoubleFree,
};

pub const PhysicalMemoryRegion = struct {
    base: u64,
    length: u64,
    usable: bool,
};

pub const FrameAllocator = struct {
    bitmap: []u8,
    total_frames: usize,
    base_addr: u64,

    /// `bitmap` must contain at least `ceil(total_frames / 8)` bytes and is
    /// fully owned by the allocator (all bits start cleared = free).
    pub fn init(base_addr: u64, total_frames: usize, bitmap: []u8) FrameAllocError!FrameAllocator {
        const required_bytes = (total_frames + 7) / 8;
        if (bitmap.len < required_bytes) {
            return error.InvalidBitmapSize;
        }
        @memset(bitmap, 0);
        return .{ .bitmap = bitmap, .total_frames = total_frames, .base_addr = base_addr };
    }

    fn frameIndexForAddr(self: FrameAllocator, addr: u64) FrameAllocError!usize {
        if (addr < self.base_addr) return error.OutOfRange;
        if ((addr - self.base_addr) % PAGE_SIZE != 0) return error.UnalignedAddress;
        const index = (addr - self.base_addr) / PAGE_SIZE;
        if (index >= self.total_frames) return error.OutOfRange;
        return @intCast(index);
    }

    fn isSet(self: FrameAllocator, index: usize) bool {
        return (self.bitmap[index / 8] & (@as(u8, 1) << @intCast(index % 8))) != 0;
    }

    fn setBit(self: *FrameAllocator, index: usize) void {
        self.bitmap[index / 8] |= (@as(u8, 1) << @intCast(index % 8));
    }

    fn clearBit(self: *FrameAllocator, index: usize) void {
        self.bitmap[index / 8] &= ~(@as(u8, 1) << @intCast(index % 8));
    }

    /// Marks every frame overlapping `region` as used (for reserved/boot
    /// regions) or leaves it free (for usable runtime regions), rounding the
    /// region down/up to whole frames.
    pub fn reserveRegion(self: *FrameAllocator, region: PhysicalMemoryRegion) FrameAllocError!void {
        if (region.usable) return;
        if (region.length == 0) return;

        const start = region.base - (region.base % PAGE_SIZE);
        const end = region.base + region.length;
        var addr = start;
        while (addr < end) : (addr += PAGE_SIZE) {
            if (addr < self.base_addr) continue;
            const index = self.frameIndexForAddr(addr) catch continue;
            self.setBit(index);
        }
    }

    /// First-fit allocation of a single physical frame. Returns the physical
    /// base address of the allocated frame.
    pub fn allocFrame(self: *FrameAllocator) FrameAllocError!u64 {
        var index: usize = 0;
        while (index < self.total_frames) : (index += 1) {
            if (!self.isSet(index)) {
                self.setBit(index);
                return self.base_addr + index * PAGE_SIZE;
            }
        }
        return error.OutOfMemory;
    }

    pub fn freeFrame(self: *FrameAllocator, addr: u64) FrameAllocError!void {
        const index = try self.frameIndexForAddr(addr);
        if (!self.isSet(index)) {
            return error.DoubleFree;
        }
        self.clearBit(index);
    }

    pub fn countFree(self: FrameAllocator) usize {
        var free: usize = 0;
        var index: usize = 0;
        while (index < self.total_frames) : (index += 1) {
            if (!self.isSet(index)) free += 1;
        }
        return free;
    }

    pub fn countUsed(self: FrameAllocator) usize {
        return self.total_frames - self.countFree();
    }
};

test "init rejects undersized bitmap" {
    var tiny: [1]u8 = undefined;
    try std.testing.expectError(error.InvalidBitmapSize, FrameAllocator.init(0, 64, tiny[0..]));
}

test "alloc and free single frame" {
    var bitmap: [8]u8 = undefined;
    var fa = try FrameAllocator.init(0x1000, 16, bitmap[0..]);

    const addr = try fa.allocFrame();
    try std.testing.expectEqual(@as(u64, 0x1000), addr);
    try std.testing.expectEqual(@as(usize, 15), fa.countFree());

    try fa.freeFrame(addr);
    try std.testing.expectEqual(@as(usize, 16), fa.countFree());
}

test "double free is rejected" {
    var bitmap: [8]u8 = undefined;
    var fa = try FrameAllocator.init(0x1000, 16, bitmap[0..]);
    try std.testing.expectError(error.DoubleFree, fa.freeFrame(0x1000));
}

test "reserveRegion marks overlapping frames used" {
    var bitmap: [8]u8 = undefined;
    var fa = try FrameAllocator.init(0x0, 16, bitmap[0..]);

    try fa.reserveRegion(.{ .base = 0x1000, .length = 0x2000, .usable = false });
    try std.testing.expectEqual(@as(usize, 14), fa.countFree());

    // Usable regions are left untouched (already free).
    try fa.reserveRegion(.{ .base = 0x5000, .length = 0x1000, .usable = true });
    try std.testing.expectEqual(@as(usize, 14), fa.countFree());
}

test "allocFrame returns OutOfMemory once exhausted" {
    var bitmap: [1]u8 = undefined;
    var fa = try FrameAllocator.init(0x0, 4, bitmap[0..]);
    _ = try fa.allocFrame();
    _ = try fa.allocFrame();
    _ = try fa.allocFrame();
    _ = try fa.allocFrame();
    try std.testing.expectError(error.OutOfMemory, fa.allocFrame());
}

test "unaligned or out-of-range addresses are rejected on free" {
    var bitmap: [8]u8 = undefined;
    var fa = try FrameAllocator.init(0x1000, 16, bitmap[0..]);
    try std.testing.expectError(error.UnalignedAddress, fa.freeFrame(0x1001));
    try std.testing.expectError(error.OutOfRange, fa.freeFrame(0x100000));
}
