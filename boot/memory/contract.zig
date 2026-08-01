const contract = @import("../entry/contract.zig");

pub const PageTableStrategy = enum {
    identity_map_low,
    identity_map_flat,
};

pub const EarlyMemoryLayout = struct {
    arch: contract.BootArch,
    page_table_strategy: PageTableStrategy,
    regions: [4]contract.MemoryRegion,
    region_count: u8,
};

pub fn pageTableStrategyForArch(arch: contract.BootArch) PageTableStrategy {
    return switch (arch) {
        .x86_64, .aarch64 => .identity_map_low,
        .riscv64 => .identity_map_flat,
    };
}

pub fn earlyMemoryLayoutFromHandoff(handoff: contract.BootHandoff) EarlyMemoryLayout {
    return .{
        .arch = handoff.arch,
        .page_table_strategy = pageTableStrategyForArch(handoff.arch),
        .regions = handoff.memory_regions,
        .region_count = handoff.memory_region_count,
    };
}

pub fn validateEarlyMemoryLayout(layout: EarlyMemoryLayout) contract.BootError!void {
    if (layout.region_count == 0 or layout.region_count > layout.regions.len) {
        return error.InvalidMemoryMap;
    }

    var idx: usize = 0;
    var has_runtime_region = false;
    while (idx < layout.region_count) : (idx += 1) {
        const region = layout.regions[idx];
        if (region.length == 0) {
            return error.InvalidMemoryMap;
        }
        if (region.kind == .runtime) {
            has_runtime_region = true;
        }
    }

    if (!has_runtime_region) {
        return error.InvalidMemoryMap;
    }
}
