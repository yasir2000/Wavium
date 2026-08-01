//! wavium-percore-alloc: ultra-low-latency, per-core memory allocation.
//!
//! Every CPU core owns an independent `CoreAllocator` built from four
//! layers (matching the prompt's architecture diagram):
//!
//!   Region  - coarse per-core backing memory carved out once at boot.
//!   Slab    - fixed-size-class pools carved from a core's `Region`.
//!   Pool    - a single size class's free-index stack (used by `Slab`).
//!   Arena   - bump/watermark allocator for phase-scoped allocations.
//!
//! Requirements covered:
//!   - No allocator lock contention: the owning core's alloc/free path
//!     touches only its own `Slab`/`Pool`/`Arena`/`Region`, none of
//!     which use a lock or an atomic operation.
//!   - Thread-safe ownership: every `CoreAllocator` is tagged with the
//!     `core_id` that owns it; `CoreAllocator.free` dispatches to the
//!     local or remote path based on the calling core's id.
//!   - Remote free support: `remote_free.RemoteFreeQueue` is a
//!     lock-free bounded MPSC queue that any core may push into; only
//!     the owner ever pops from it, via `reclaimRemote`.
//!   - Cache locality: each core's memory lives in its own `Region`
//!     and `Slab` pools, never interleaved with another core's memory.
//!   - Memory recycling: `Pool`'s free-index stack and `Arena`/`Region`
//!     watermark resets both recycle memory without a general-purpose
//!     allocator's fragmentation.
//!   - Huge page support (future): see `huge_page_size_bytes` below -
//!     reserved for a future `Region` backed by huge pages; not yet
//!     wired up since this runtime has no page-table/MMU layer here.

const std = @import("std");
const testing = std.testing;

pub const arena = @import("arena.zig");
pub const pool = @import("pool.zig");
pub const slab = @import("slab.zig");
pub const region = @import("region.zig");
pub const remote_free = @import("remote_free.zig");
pub const core_allocator = @import("core_allocator.zig");
pub const benchmark = @import("benchmark.zig");

pub const Arena = arena.Arena;
pub const Pool = pool.Pool;
pub const Slab = slab.Slab;
pub const Region = region.Region;
pub const RemoteFreeQueue = remote_free.RemoteFreeQueue;
pub const CoreAllocator = core_allocator.CoreAllocator;
pub const CoreId = core_allocator.CoreId;

/// Reserved for future huge-page-backed `Region`s (2 MiB pages). Not
/// yet implemented: this runtime has no MMU/page-table layer to back
/// it with today, so this is a documented placeholder rather than a
/// functional API.
pub const huge_page_size_bytes: usize = 2 * 1024 * 1024;

pub fn moduleName() []const u8 {
    return "wavium-percore-alloc";
}

test "moduleName reports the expected module name" {
    try testing.expectEqualStrings("wavium-percore-alloc", moduleName());
}

test "end-to-end: two cores allocate independently and free across cores" {
    var core0 = CoreAllocator.init(0);
    var core1 = CoreAllocator.init(1);

    // Each core allocates from its own Slab - no shared state at all.
    const block0 = try core0.alloc(64);
    const block1 = try core1.alloc(64);
    try testing.expect(@intFromPtr(block0.ptr) != @intFromPtr(block1.ptr));

    // Core 1 frees a block it does NOT own - this must be deferred to
    // core 0's remote-free queue rather than touching core 0's Slab
    // directly from core 1.
    try core0.free(block0, 64, 1);
    try testing.expectEqual(@as(usize, slab.blocks_per_class - 1), core0.slab.pool_64.available());

    // Core 0 later reclaims the deferred remote free itself.
    core0.reclaimRemote();
    try testing.expectEqual(@as(usize, slab.blocks_per_class), core0.slab.pool_64.available());

    // Core 1's own local free path is untouched by any of this.
    try core1.free(block1, 64, 1);
    try testing.expectEqual(@as(usize, slab.blocks_per_class), core1.slab.pool_64.available());
}

test "end-to-end: Region backs an Arena for phase-scoped allocations" {
    var backing: [256]u8 = undefined;
    var r = Region.init(&backing);
    const arena_backing = try r.carve(128);

    var a = Arena.init(arena_backing);
    _ = try a.alloc(32);
    _ = try a.alloc(32);
    try testing.expectEqual(@as(usize, 64), a.used());
    a.reset();
    try testing.expectEqual(@as(usize, 0), a.used());
}
