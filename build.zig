const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const module_paths = [_][]const u8{
        "modules/wavium-core/src/lib.zig",
        "modules/wavium-memory/src/lib.zig",
        "modules/wavium-scheduler/src/lib.zig",
        "modules/wavium-security/src/lib.zig",
        "modules/wavium-fabric/src/lib.zig",
        "modules/wavium-state/src/lib.zig",
        "modules/wavium-actor/src/lib.zig",
        "modules/wavium-wasm/src/lib.zig",
        "modules/wavium-component/src/lib.zig",
        "modules/wavium-wit/src/lib.zig",
        "modules/wavium-wasi/src/lib.zig",
        "modules/wavium-hal/src/lib.zig",
        "modules/wavium-federation/src/lib.zig",
        "modules/wavium-sdk/src/lib.zig",
        "modules/wavium-toolchain/src/lib.zig",
        "modules/wavium-build/src/lib.zig",
        "modules/wavium-boot/src/lib.zig",
        "modules/wavium-freestanding/src/lib.zig",
        "modules/wavium-component-tools/src/lib.zig",
        "modules/wavium-bindgen/src/lib.zig",
        "modules/wavium-sandbox/src/lib.zig",
        "modules/wavium-debug/src/lib.zig",
        "modules/wavium-profiler/src/lib.zig",
        "modules/wavium-security-tools/src/lib.zig",
        "modules/wavium-deploy/src/lib.zig",
        "modules/wavium-devkit/src/lib.zig",
        "modules/wavium-sim/src/lib.zig",
        "modules/wavium-ci/src/lib.zig",
    };

    inline for (module_paths) |p| {
        _ = b.addModule(p, .{
            .root_source_file = b.path(p),
            .target = target,
            .optimize = optimize,
        });
    }

    const test_step = b.step("test", "Run module tests");

    inline for (module_paths) |p| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(p),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
    }

    const cli_test = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("modules/wavium-cli/src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_cli_test = b.addRunArtifact(cli_test);
    test_step.dependOn(&run_cli_test.step);

    const boundary_root = b.createModule(.{
        .root_source_file = b.path("tests/component/api_boundaries.zig"),
        .target = target,
        .optimize = optimize,
    });

    boundary_root.addImport("wavium-wasm", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wasm/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    boundary_root.addImport("wavium-component", b.createModule(.{
        .root_source_file = b.path("modules/wavium-component/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    boundary_root.addImport("wavium-wit", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wit/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    boundary_root.addImport("wavium-wasi", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wasi/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    boundary_root.addImport("wavium-security", b.createModule(.{
        .root_source_file = b.path("modules/wavium-security/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const boundary_tests = b.addTest(.{ .root_module = boundary_root });
    const run_boundary_tests = b.addRunArtifact(boundary_tests);
    test_step.dependOn(&run_boundary_tests.step);

    const integration_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/e2e_component_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    integration_root.addImport("wavium-wasm", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wasm/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    integration_root.addImport("wavium-component", b.createModule(.{
        .root_source_file = b.path("modules/wavium-component/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    integration_root.addImport("wavium-wit", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wit/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    integration_root.addImport("wavium-wasi", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wasi/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    integration_root.addImport("wavium-security", b.createModule(.{
        .root_source_file = b.path("modules/wavium-security/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const integration_tests = b.addTest(.{ .root_module = integration_root });
    const run_integration_tests = b.addRunArtifact(integration_tests);
    test_step.dependOn(&run_integration_tests.step);

    const federation_integration_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/federation_migration_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    federation_integration_root.addImport("wavium-actor", b.createModule(.{
        .root_source_file = b.path("modules/wavium-actor/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    federation_integration_root.addImport("wavium-state", b.createModule(.{
        .root_source_file = b.path("modules/wavium-state/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    federation_integration_root.addImport("wavium-federation", b.createModule(.{
        .root_source_file = b.path("modules/wavium-federation/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    federation_integration_root.addImport("wavium-security", b.createModule(.{
        .root_source_file = b.path("modules/wavium-security/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const federation_integration_tests = b.addTest(.{ .root_module = federation_integration_root });
    const run_federation_integration_tests = b.addRunArtifact(federation_integration_tests);
    test_step.dependOn(&run_federation_integration_tests.step);

    const messaging_integration_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/fabric_actor_messaging_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    messaging_integration_root.addImport("wavium-fabric", b.createModule(.{
        .root_source_file = b.path("modules/wavium-fabric/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    messaging_integration_root.addImport("wavium-actor", b.createModule(.{
        .root_source_file = b.path("modules/wavium-actor/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const messaging_integration_tests = b.addTest(.{ .root_module = messaging_integration_root });
    const run_messaging_integration_tests = b.addRunArtifact(messaging_integration_tests);
    test_step.dependOn(&run_messaging_integration_tests.step);

    const build_sign_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/build_sign_verify_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    build_sign_root.addImport("wavium-build", b.createModule(.{
        .root_source_file = b.path("modules/wavium-build/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    build_sign_root.addImport("wavium-security-tools", b.createModule(.{
        .root_source_file = b.path("modules/wavium-security-tools/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const build_sign_tests = b.addTest(.{ .root_module = build_sign_root });
    const run_build_sign_tests = b.addRunArtifact(build_sign_tests);
    test_step.dependOn(&run_build_sign_tests.step);

    const bindgen_flow_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/wit_bindgen_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    bindgen_flow_root.addImport("wavium-wit", b.createModule(.{
        .root_source_file = b.path("modules/wavium-wit/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    bindgen_flow_root.addImport("wavium-bindgen", b.createModule(.{
        .root_source_file = b.path("modules/wavium-bindgen/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const bindgen_flow_tests = b.addTest(.{ .root_module = bindgen_flow_root });
    const run_bindgen_flow_tests = b.addRunArtifact(bindgen_flow_tests);
    test_step.dependOn(&run_bindgen_flow_tests.step);

    const component_tools_flow_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/component_tools_pipeline_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    component_tools_flow_root.addImport("wavium-component-tools", b.createModule(.{
        .root_source_file = b.path("modules/wavium-component-tools/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    component_tools_flow_root.addImport("wavium-build", b.createModule(.{
        .root_source_file = b.path("modules/wavium-build/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    component_tools_flow_root.addImport("wavium-security-tools", b.createModule(.{
        .root_source_file = b.path("modules/wavium-security-tools/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const component_tools_flow_tests = b.addTest(.{ .root_module = component_tools_flow_root });
    const run_component_tools_flow_tests = b.addRunArtifact(component_tools_flow_tests);
    test_step.dependOn(&run_component_tools_flow_tests.step);

    const deploy_trust_root = b.createModule(.{
        .root_source_file = b.path("tests/integration/deploy_trust_flow.zig"),
        .target = target,
        .optimize = optimize,
    });

    deploy_trust_root.addImport("wavium-build", b.createModule(.{
        .root_source_file = b.path("modules/wavium-build/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    deploy_trust_root.addImport("wavium-security-tools", b.createModule(.{
        .root_source_file = b.path("modules/wavium-security-tools/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));
    deploy_trust_root.addImport("wavium-deploy", b.createModule(.{
        .root_source_file = b.path("modules/wavium-deploy/src/lib.zig"),
        .target = target,
        .optimize = optimize,
    }));

    const deploy_trust_tests = b.addTest(.{ .root_module = deploy_trust_root });
    const run_deploy_trust_tests = b.addRunArtifact(deploy_trust_tests);
    test_step.dependOn(&run_deploy_trust_tests.step);
}
