//! wavium-massive-parallel: scalable runtime infrastructure for 8 up
//! to 1024 logical CPUs (Prompt 27 of the Wavium Engineering Prompt
//! Suite).
//!
//! Requirements addressed:
//! - Scalable runtime across 8/16/32/64/128/256/512/1024 logical CPUs
//!   (`scaling.supported_core_counts`, `scaling.isSupportedScale`).
//! - No centralized scheduler: this module intentionally contains no
//!   single global scheduler type - per-core scheduling already lives
//!   in `wavium-coresched` (Prompt 17) and `wavium-work-steal`
//!   (Prompt 23); this module supplies the sharded/distributed data
//!   structures those per-core schedulers need to stay decentralized
//!   at massive scale.
//! - Distributed metadata (`metadata.DistributedMetadataStore`).
//! - Distributed actor registry (`registry.DistributedActorRegistry`).
//! - Distributed allocator (`allocator.DistributedAllocatorRouter`).
//! - Distributed timers (`timers.DistributedTimers`).
//! - Distributed queues (`queues.DistributedQueues`).
//! - Minimal synchronization: every structure above is either
//!   sharded (registry/metadata, via `sharding.computeShard` - a core
//!   only ever touches the one shard owning a given key) or strictly
//!   per-core (timers/queues/allocator - a core only ever touches its
//!   own slot, with cross-core movement only via explicit, occasional
//!   `steal`), plus `scaling.groupCountFor`/`groupOf` for hierarchical
//!   fan-out so any higher-level aggregation only ever needs to
//!   synchronize with ~sqrt(core_count) peers instead of every core.
//!
//! See `docs/architecture/massive-parallel-scalability.md` for the
//! full scalability-strategy writeup this prompt also requires.

const std = @import("std");
const testing = std.testing;

pub const scaling = @import("scaling.zig");
pub const sharding = @import("sharding.zig");
pub const registry = @import("registry.zig");
pub const metadata = @import("metadata.zig");
pub const timers = @import("timers.zig");
pub const queues = @import("queues.zig");
pub const allocator = @import("allocator.zig");

pub const DistributedActorRegistry = registry.DistributedActorRegistry;
pub const DistributedMetadataStore = metadata.DistributedMetadataStore;
pub const DistributedTimers = timers.DistributedTimers;
pub const DistributedQueues = queues.DistributedQueues;
pub const DistributedAllocatorRouter = allocator.DistributedAllocatorRouter;

pub fn moduleName() []const u8 {
    return "wavium-massive-parallel";
}

test "moduleName reports the expected module name" {
    try testing.expectEqualStrings("wavium-massive-parallel", moduleName());
}

var it_next_address: usize = 0x2000;

fn itAlloc(core_id: usize, size: usize) allocator.AllocError!usize {
    _ = core_id;
    const addr = it_next_address;
    it_next_address += size;
    return addr;
}

fn itFree(core_id: usize, address: usize, size: usize) void {
    _ = core_id;
    _ = address;
    _ = size;
}

test "end-to-end: 64-core deployment exercises every distributed subsystem with minimal synchronization" {
    const core_count: usize = 64;
    try testing.expect(scaling.isSupportedScale(core_count));
    const groups = scaling.groupCountFor(core_count);
    try testing.expect(groups < core_count);

    // Distributed actor registry: register actors sharded by id, look
    // them up back without any core needing a global lock.
    var actor_registry = DistributedActorRegistry(64).init(groups);
    try actor_registry.register(1001, 5);
    try actor_registry.register(2002, 40);
    try testing.expectEqual(@as(registry.CoreId, 5), try actor_registry.lookup(1001));
    try testing.expectEqual(@as(registry.CoreId, 40), try actor_registry.lookup(2002));

    // Distributed metadata: sharded cluster config store.
    var meta = DistributedMetadataStore(u32, 64, 8).init(groups);
    try meta.put(7, 4096);
    try testing.expectEqual(@as(u32, 4096), try meta.get(7));

    // Distributed timers: core 3 and core 50 each own an independent
    // wheel; arming one never touches the other.
    var timer_set = DistributedTimers(core_count, 8).init(core_count);
    try timer_set.arm(3, 1, 100);
    try timer_set.arm(50, 2, 10);
    var expired: [4]timers.TimerId = undefined;
    try testing.expectEqual(@as(usize, 0), timer_set.popExpired(3, 50, &expired));
    try testing.expectEqual(@as(usize, 1), timer_set.popExpired(50, 50, &expired));

    // Distributed queues: core 0 gets overloaded, core 1 steals half.
    var queue_set = DistributedQueues(u32, core_count, 8).init(core_count);
    try queue_set.push(0, 10);
    try queue_set.push(0, 20);
    try queue_set.push(0, 30);
    try queue_set.push(0, 40);
    const stolen = try queue_set.steal(0, 1);
    try testing.expectEqual(@as(usize, 2), stolen);

    // Distributed allocator: every core routes through its own seam.
    const alloc_router = DistributedAllocatorRouter.init(core_count, itAlloc, itFree);
    const addr = try alloc_router.allocOn(40, 128);
    try testing.expect(addr != 0);
    alloc_router.freeOn(40, addr, 128);
}
