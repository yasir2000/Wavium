const std = @import("std");

/// Lock-free concurrent runtime infrastructure: bounded SPSC/MPSC/MPMC
/// queues, a lock-free stack, a lock-free freelist, a plain ring buffer,
/// an atomic bitmap, a fixed-capacity concurrent hash map, and
/// epoch-based reclamation. Everything here is allocator-free (fixed
/// capacity, caller-owned storage) and uses Zig atomics/CAS directly - no
/// OS mutexes, since this runtime has no operating system underneath it.
pub fn moduleName() []const u8 {
    return "wavium-lockfree";
}

pub const ring_buffer = @import("ring_buffer.zig");
pub const spsc_queue = @import("spsc_queue.zig");
pub const mpsc_queue = @import("mpsc_queue.zig");
pub const mpmc_queue = @import("mpmc_queue.zig");
pub const freelist = @import("freelist.zig");
pub const stack = @import("stack.zig");
pub const bitmap = @import("bitmap.zig");
pub const hashmap = @import("hashmap.zig");
pub const reclamation = @import("reclamation.zig");
pub const benchmark = @import("benchmark.zig");

test "moduleName" {
    try std.testing.expectEqualStrings("wavium-lockfree", moduleName());
}

fn keyHash(key: u32) u64 {
    return std.hash.Wyhash.hash(0, std.mem.asBytes(&key));
}
fn keyEq(a: u32, b: u32) bool {
    return a == b;
}

test "end-to-end: queues, stack, bitmap, hashmap, and epoch reclamation composed together" {
    // MPMC queue moves work items between simulated cores.
    var work_queue = mpmc_queue.MpmcQueue(u32, 8).init();
    try std.testing.expect(work_queue.push(1));
    try std.testing.expect(work_queue.push(2));

    // A lock-free stack acts as a free-object pool.
    var pool = stack.LockFreeStack(u32, 4).init();
    try std.testing.expect(pool.push(100));
    try std.testing.expect(pool.push(200));

    // An atomic bitmap tracks which of a fixed set of resources are busy.
    var busy = bitmap.AtomicBitmap(8).init();
    try std.testing.expect(!busy.testAndSet(2));
    try std.testing.expect(busy.testAndSet(2));

    // A concurrent hash map records ownership of a resource by a core id.
    var owners = hashmap.ConcurrentHashMap(u32, u32, 8, keyHash, keyEq).init();
    try std.testing.expect(owners.insert(2, 0)); // resource 2 owned by core 0

    // Draining the queue and consulting the map/pool/bitmap together:
    const item = work_queue.pop().?;
    try std.testing.expectEqual(@as(u32, 1), item);
    try std.testing.expectEqual(@as(u32, 0), owners.get(2).?);
    try std.testing.expectEqual(@as(u32, 200), pool.pop().?);

    // Epoch-based reclamation guards recycling a retired pool slot.
    var reclaimer = reclamation.EpochReclaimer(2, 4).init();
    reclaimer.enter(0);
    reclaimer.advanceEpoch();
    try reclaimer.retire(0);

    var reclaimed: [2]u32 = undefined;
    try std.testing.expectEqual(@as(usize, 0), reclaimer.reclaim(reclaimed[0..]));
    reclaimer.leave(0);
    try std.testing.expectEqual(@as(usize, 1), reclaimer.reclaim(reclaimed[0..]));
}
