//! The five runtime services this prompt requires to become
//! per-CPU/per-NUMA-node distributed instances instead of one global
//! singleton each.

pub const ServiceKind = enum(u3) {
    memory_manager,
    scheduler,
    capability_manager,
    registry,
    timers,
};

pub const service_kinds = [_]ServiceKind{
    .memory_manager,
    .scheduler,
    .capability_manager,
    .registry,
    .timers,
};

pub fn serviceName(kind: ServiceKind) []const u8 {
    return switch (kind) {
        .memory_manager => "memory_manager",
        .scheduler => "scheduler",
        .capability_manager => "capability_manager",
        .registry => "registry",
        .timers => "timers",
    };
}

const testing = @import("std").testing;

test "serviceName covers every ServiceKind" {
    try testing.expectEqualStrings("memory_manager", serviceName(.memory_manager));
    try testing.expectEqualStrings("scheduler", serviceName(.scheduler));
    try testing.expectEqualStrings("capability_manager", serviceName(.capability_manager));
    try testing.expectEqualStrings("registry", serviceName(.registry));
    try testing.expectEqualStrings("timers", serviceName(.timers));
}

test "service_kinds lists exactly the 5 required services" {
    try testing.expectEqual(@as(usize, 5), service_kinds.len);
}
