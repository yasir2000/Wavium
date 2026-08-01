const std = @import("std");

/// The logical reason an IPI was sent. Every cross-core notification this
/// runtime needs (remote actor wake-up, cross-core scheduling, cross-core
/// memory synchronization, remote mailbox notification) is modeled as one
/// of these vectors rather than a raw interrupt number, so callers stay
/// portable across the x86 APIC / ARM GIC / RISC-V CLINT+SBI backends.
pub const IpiVector = enum(u8) {
    wake = 0,
    reschedule = 1,
    memory_sync = 2,
    mailbox_notify = 3,
    halt = 4,
};

test "IpiVector values are stable small integers suitable as interrupt vectors" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(IpiVector.wake));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(IpiVector.halt));
}
