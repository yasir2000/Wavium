//! CoreAllocator: the per-core allocator facade described by the
//! prompt's "Core N -> Arena / Pool / Slab / Region" architecture. One
//! `CoreAllocator` is instantiated per CPU core and is never shared -
//! each core's fast-path `alloc`/`freeLocal` calls touch only its own
//! `Region`-backed `Slab`, with no lock and no atomic operation
//! anywhere on that path (no allocator lock contention).
//!
//! Ownership is thread-safe by construction rather than by locking:
//! every allocation is implicitly tagged with the `core_id` of the
//! `CoreAllocator` that served it, and callers are expected to route
//! frees through `free(block, size, calling_core)`, which sends the
//! request down the lock-free path only when `calling_core` differs
//! from the owner (remote free support). The owner drains those
//! deferred requests back into its own `Slab` via `reclaimRemote`,
//! which is the only place contention could occur - and even there
//! it's a wait-free MPSC pop, not a lock.

const std = @import("std");
const testing = std.testing;
const region_mod = @import("region.zig");
const slab_mod = @import("slab.zig");
const remote_free_mod = @import("remote_free.zig");

pub const CoreId = u16;

pub const CoreAllocatorError = error{ OutOfMemory, InvalidBlock, QueueFull };

pub const remote_free_capacity = 64;

pub const FreeRequest = struct { ptr: usize, size: usize };

pub const CoreAllocator = struct {
    core_id: CoreId,
    slab: slab_mod.Slab,
    remote_frees: remote_free_mod.RemoteFreeQueue(FreeRequest, remote_free_capacity),

    pub fn init(core_id: CoreId) CoreAllocator {
        return .{
            .core_id = core_id,
            .slab = slab_mod.Slab.init(),
            .remote_frees = remote_free_mod.RemoteFreeQueue(FreeRequest, remote_free_capacity).init(),
        };
    }

    /// Fast path: served directly from this core's own `Slab`. No
    /// lock, no atomic, no cross-core visibility required.
    pub fn alloc(self: *CoreAllocator, size: usize) CoreAllocatorError![]u8 {
        return self.slab.alloc(size) catch CoreAllocatorError.OutOfMemory;
    }

    /// Owner-only fast path free: must only ever be called by the core
    /// that owns this allocator.
    pub fn freeLocal(self: *CoreAllocator, block: []u8, size: usize) CoreAllocatorError!void {
        self.slab.free(size, block) catch return CoreAllocatorError.InvalidBlock;
    }

    /// Cross-core free: pushes onto the lock-free remote-free queue
    /// instead of touching the owner's `Slab` directly. The owner
    /// reclaims these later via `reclaimRemote`.
    pub fn freeRemote(self: *CoreAllocator, block: []u8, size: usize) CoreAllocatorError!void {
        self.remote_frees.push(.{ .ptr = @intFromPtr(block.ptr), .size = size }) catch
            return CoreAllocatorError.QueueFull;
    }

    /// Thread-safe ownership dispatch: routes to the lock-free fast
    /// path or the lock-free remote-free queue depending on whether
    /// the caller is this allocator's owning core.
    pub fn free(self: *CoreAllocator, block: []u8, size: usize, calling_core: CoreId) CoreAllocatorError!void {
        if (calling_core == self.core_id) {
            try self.freeLocal(block, size);
        } else {
            try self.freeRemote(block, size);
        }
    }

    /// Drains every queued remote-free request back into this core's
    /// own `Slab`. Must only be called by the owning core (e.g. once
    /// per scheduling quantum), keeping remote frees fully asynchronous
    /// with respect to the owner's alloc/free fast path.
    pub fn reclaimRemote(self: *CoreAllocator) void {
        while (self.remote_frees.pop()) |req| {
            const ptr: [*]u8 = @ptrFromInt(req.ptr);
            const block = ptr[0..req.size];
            self.slab.free(req.size, block) catch {};
        }
    }
};

test "CoreAllocator serves and recycles a local allocation" {
    var core = CoreAllocator.init(0);
    const block = try core.alloc(32);
    try core.free(block, 32, 0);
}

test "CoreAllocator defers a remote free instead of touching Slab directly" {
    var core = CoreAllocator.init(0);
    const block = try core.alloc(32);

    // A different core (id 1) frees a block owned by core 0. The
    // request is queued, not yet applied to the Slab.
    try core.free(block, 32, 1);
    try testing.expectEqual(@as(usize, slab_mod.blocks_per_class - 1), core.slab.pool_32.available());

    core.reclaimRemote();
    try testing.expectEqual(@as(usize, slab_mod.blocks_per_class), core.slab.pool_32.available());
}

test "CoreAllocator reports OutOfMemory once a class is exhausted" {
    var core = CoreAllocator.init(0);
    var i: usize = 0;
    while (i < slab_mod.blocks_per_class) : (i += 1) _ = try core.alloc(16);
    try testing.expectError(CoreAllocatorError.OutOfMemory, core.alloc(16));
}

test "Region can back an independent CoreAllocator-adjacent buffer" {
    var backing: [256]u8 = undefined;
    var region = region_mod.Region.init(&backing);
    const span = try region.carve(128);
    try testing.expectEqual(@as(usize, 128), span.len);
}
