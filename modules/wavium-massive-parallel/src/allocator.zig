//! Distributed allocator: rather than one global heap/allocator every
//! core must synchronize on, requests are routed to a per-core
//! allocation seam. This mirrors `wavium-percore-alloc`'s (Prompt 22)
//! per-core-ownership philosophy at the routing layer without
//! importing it directly - `AllocFn`/`FreeFn` are function-pointer
//! seams (same decoupling pattern as `ExecutionBackend`/
//! `DriverLifecycle`/`NodeAllocator.AllocFn`) so this module can be
//! bound to `wavium-percore-alloc`'s `CoreAllocator`, a NUMA-aware
//! allocator, or a test double without any cross-import.

pub const AllocError = error{
    AllocationFailed,
    InvalidCore,
};

pub const AllocFn = *const fn (core_id: usize, size: usize) AllocError!usize;
pub const FreeFn = *const fn (core_id: usize, address: usize, size: usize) void;

pub const DistributedAllocatorRouter = struct {
    core_count: usize,
    alloc_fn: AllocFn,
    free_fn: FreeFn,

    const Self = @This();

    pub fn init(core_count: usize, alloc_fn: AllocFn, free_fn: FreeFn) Self {
        return .{ .core_count = core_count, .alloc_fn = alloc_fn, .free_fn = free_fn };
    }

    /// Routes an allocation request to `core_id`'s own allocator -
    /// every core allocates from its own arena/pool, so allocation
    /// never contends with any other core.
    pub fn allocOn(self: *const Self, core_id: usize, size: usize) AllocError!usize {
        if (core_id >= self.core_count) return AllocError.InvalidCore;
        return self.alloc_fn(core_id, size);
    }

    pub fn freeOn(self: *const Self, core_id: usize, address: usize, size: usize) void {
        self.free_fn(core_id, address, size);
    }
};

const testing = @import("std").testing;

var test_next_address: usize = 0x1000;
var test_free_count: usize = 0;

fn fakeAlloc(core_id: usize, size: usize) AllocError!usize {
    _ = core_id;
    if (size == 0) return AllocError.AllocationFailed;
    const addr = test_next_address;
    test_next_address += size;
    return addr;
}

fn fakeFree(core_id: usize, address: usize, size: usize) void {
    _ = core_id;
    _ = address;
    _ = size;
    test_free_count += 1;
}

test "DistributedAllocatorRouter routes alloc/free to the requesting core" {
    const router = DistributedAllocatorRouter.init(4, fakeAlloc, fakeFree);
    const addr = try router.allocOn(2, 64);
    try testing.expect(addr != 0);
    router.freeOn(2, addr, 64);
    try testing.expectEqual(@as(usize, 1), test_free_count);
}

test "DistributedAllocatorRouter rejects an out-of-range core id" {
    const router = DistributedAllocatorRouter.init(4, fakeAlloc, fakeFree);
    try testing.expectError(AllocError.InvalidCore, router.allocOn(99, 16));
}
