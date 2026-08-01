//! Kinds of processing units the runtime may schedule execution onto
//! in the future. Deliberately just an identity enum today - per the
//! prompt's explicit "do not implement hardware-specific code yet"
//! constraint, no kind here has any backing implementation, only a
//! name and a set of capabilities it is expected to offer (see
//! `capability.zig`).

pub const ExecutionTargetKind = enum(u4) {
    cpu_big,
    cpu_little,
    gpu,
    npu,
    dpu,
    smartnic,
    fpga,
    ai_accelerator,
    tpu,
};

pub const execution_target_kinds = [_]ExecutionTargetKind{
    .cpu_big,
    .cpu_little,
    .gpu,
    .npu,
    .dpu,
    .smartnic,
    .fpga,
    .ai_accelerator,
    .tpu,
};

pub fn kindName(kind: ExecutionTargetKind) []const u8 {
    return switch (kind) {
        .cpu_big => "cpu_big",
        .cpu_little => "cpu_little",
        .gpu => "gpu",
        .npu => "npu",
        .dpu => "dpu",
        .smartnic => "smartnic",
        .fpga => "fpga",
        .ai_accelerator => "ai_accelerator",
        .tpu => "tpu",
    };
}

const testing = @import("std").testing;

test "execution_target_kinds lists exactly the 9 future hardware kinds" {
    try testing.expectEqual(@as(usize, 9), execution_target_kinds.len);
}

test "kindName covers every ExecutionTargetKind" {
    for (execution_target_kinds) |kind| {
        try testing.expect(kindName(kind).len > 0);
    }
}
