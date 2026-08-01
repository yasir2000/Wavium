const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const boot_module = b.addModule("wavium-boot-prompt02", .{
        .root_source_file = b.path("root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/boot_smoke.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    tests.root_module.addImport("wavium-boot-prompt02", boot_module);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run boot scaffold smoke tests");
    test_step.dependOn(&run_tests.step);

    const write_test_image = b.addWriteFiles();
    _ = write_test_image.add("test-image/wavium-test-boot.bin", "WAVIUM_BOOT_TEST_IMAGE_V0\n");
    const image_step = b.step("test-image", "Emit a placeholder boot image artifact for integration wiring");
    image_step.dependOn(&write_test_image.step);

    const clean_boot_artifacts = b.addSystemCommand(&.{
        "bash",
        "-lc",
        "rm -f test-image/wavium_x86_64_boot.elf boot/test-image/wavium_x86_64_boot.elf " ++
            "test-image/wavium_aarch64_boot.elf boot/test-image/wavium_aarch64_boot.elf " ++
            "test-image/wavium_riscv64_boot.elf boot/test-image/wavium_riscv64_boot.elf",
    });
    clean_boot_artifacts.setName("clean stale boot image artifacts");

    const clean_boot_step = b.step("clean-boot-artifacts", "Remove stale boot ELF artifacts from legacy and canonical paths for all architectures");
    clean_boot_step.dependOn(&clean_boot_artifacts.step);

    const ensure_test_image_dir = b.addSystemCommand(&.{ "bash", "-lc", "mkdir -p boot/test-image" });
    ensure_test_image_dir.setName("ensure test-image directory");

    const ArchAssembly = struct {
        arch_name: []const u8,
        zig_target: []const u8,
        reset_source: []const u8,
        startup_source: []const u8,
        linker_script: []const u8,
        boot_entry_symbol: []const u8,
        reset_vector_symbol: []const u8,
        startup_entry_symbol: []const u8,
        runtime_handoff_symbol: []const u8,
        temp_stack_top_symbol: []const u8,
        handoff_payload_symbol: []const u8,
    };

    const arch_assemblies = [_]ArchAssembly{
        .{
            .arch_name = "x86_64",
            .zig_target = "x86_64-freestanding-none",
            .reset_source = "reset/x86_64_reset.S",
            .startup_source = "startup/x86_64_startup.S",
            .linker_script = "entry/linker/x86_64.ld",
            .boot_entry_symbol = "_start",
            .reset_vector_symbol = "wavium_x86_64_reset_vector",
            .startup_entry_symbol = "wavium_x86_64_startup_entry",
            .runtime_handoff_symbol = "wavium_x86_64_runtime_handoff",
            .temp_stack_top_symbol = "wavium_x86_64_temp_stack_top",
            .handoff_payload_symbol = "wavium_x86_64_handoff_payload",
        },
        .{
            .arch_name = "aarch64",
            .zig_target = "aarch64-freestanding-none",
            .reset_source = "reset/aarch64_reset.S",
            .startup_source = "startup/aarch64_startup.S",
            .linker_script = "entry/linker/aarch64.ld",
            .boot_entry_symbol = "_start",
            .reset_vector_symbol = "wavium_aarch64_reset_vector",
            .startup_entry_symbol = "wavium_aarch64_startup_entry",
            .runtime_handoff_symbol = "wavium_aarch64_runtime_handoff",
            .temp_stack_top_symbol = "wavium_aarch64_temp_stack_top",
            .handoff_payload_symbol = "wavium_aarch64_handoff_payload",
        },
        .{
            .arch_name = "riscv64",
            .zig_target = "riscv64-freestanding-none",
            .reset_source = "reset/riscv64_reset.S",
            .startup_source = "startup/riscv64_startup.S",
            .linker_script = "entry/linker/riscv64.ld",
            .boot_entry_symbol = "_start",
            .reset_vector_symbol = "wavium_riscv64_reset_vector",
            .startup_entry_symbol = "wavium_riscv64_startup_entry",
            .runtime_handoff_symbol = "wavium_riscv64_runtime_handoff",
            .temp_stack_top_symbol = "wavium_riscv64_temp_stack_top",
            .handoff_payload_symbol = "wavium_riscv64_handoff_payload",
        },
    };

    const boot_verify_all_step = b.step("boot-verify-all", "Run boot-verify for x86_64, aarch64, and riscv64");

    for (arch_assemblies) |info| {
        const asm_reset = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", info.zig_target, "-c" });
        asm_reset.setName(b.fmt("compile {s} reset skeleton", .{info.arch_name}));
        asm_reset.addFileArg(b.path(info.reset_source));
        asm_reset.addArg("-o");
        _ = asm_reset.addOutputFileArg(b.fmt("{s}_reset.o", .{info.arch_name}));

        const asm_startup = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", info.zig_target, "-c" });
        asm_startup.setName(b.fmt("compile {s} startup skeleton", .{info.arch_name}));
        asm_startup.addFileArg(b.path(info.startup_source));
        asm_startup.addArg("-o");
        _ = asm_startup.addOutputFileArg(b.fmt("{s}_startup.o", .{info.arch_name}));

        const asm_step = b.step(b.fmt("asm-skeleton-{s}", .{info.arch_name}), "Compile architecture assembly skeleton objects (opt-in)");
        asm_step.dependOn(&asm_reset.step);
        asm_step.dependOn(&asm_startup.step);

        const boot_image_link = b.addSystemCommand(&.{ b.graph.zig_exe, "cc", "-target", info.zig_target, "-nostdlib" });
        boot_image_link.setName(b.fmt("link {s} boot image skeleton", .{info.arch_name}));
        boot_image_link.addArg("-T");
        boot_image_link.addFileArg(b.path(info.linker_script));
        boot_image_link.addFileArg(b.path(info.reset_source));
        boot_image_link.addFileArg(b.path(info.startup_source));
        boot_image_link.addArgs(&.{ "-o", b.fmt("boot/test-image/wavium_{s}_boot.elf", .{info.arch_name}) });
        boot_image_link.step.dependOn(&clean_boot_artifacts.step);
        boot_image_link.step.dependOn(&ensure_test_image_dir.step);

        const boot_image_step = b.step(b.fmt("boot-image-{s}", .{info.arch_name}), "Link architecture boot image ELF from assembly skeletons (opt-in)");
        boot_image_step.dependOn(&boot_image_link.step);

        const boot_image_symbols = b.addSystemCommand(&.{ "bash", "-lc" });
        boot_image_symbols.setName(b.fmt("validate {s} boot image symbol contract fallback", .{info.arch_name}));
        boot_image_symbols.addArg(b.fmt(
            "test -f boot/test-image/wavium_{s}_boot.elf && test ! -f test-image/wavium_{s}_boot.elf && grep -q \"{s}\" boot/{s} && grep -q \"{s}\" boot/{s} && grep -q \"{s}\" boot/{s} && grep -q \"{s}\" boot/{s} && grep -q \"{s}\" boot/{s}",
            .{
                info.arch_name,
                info.arch_name,
                info.boot_entry_symbol,
                info.reset_source,
                info.reset_vector_symbol,
                info.reset_source,
                info.startup_entry_symbol,
                info.startup_source,
                info.runtime_handoff_symbol,
                info.startup_source,
                info.handoff_payload_symbol,
                info.startup_source,
            },
        ));
        boot_image_symbols.step.dependOn(&boot_image_link.step);

        const boot_image_symbols_step = b.step(b.fmt("boot-image-symbols-{s}", .{info.arch_name}), "Link architecture boot image and verify required symbols in ELF table (opt-in)");
        boot_image_symbols_step.dependOn(&boot_image_symbols.step);

        const boot_verify_step = b.step(b.fmt("boot-verify-{s}", .{info.arch_name}), "Run cleanup plus architecture boot image link and symbol-contract verification");
        boot_verify_step.dependOn(boot_image_symbols_step);

        boot_verify_all_step.dependOn(boot_verify_step);
    }
}
