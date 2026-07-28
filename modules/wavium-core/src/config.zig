const std = @import("std");

pub const RuntimeConfig = struct {
    max_components: u32 = 1024,
    scheduler_queue_capacity: usize = 4096,
    enable_federation: bool = false,
    enable_jit: bool = false,
};

pub fn validate(config: RuntimeConfig) !void {
    if (config.max_components == 0) return error.InvalidMaxComponents;
    if (config.scheduler_queue_capacity == 0) return error.InvalidQueueCapacity;
}
