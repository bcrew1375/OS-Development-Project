const std = @import("std");

const modules = @import("modules.zig");

pub fn addStep(b: *std.Build, optimize: std.builtin.OptimizeMode) void {
    const common_modules = modules.createCommonModules(b, b.graph.host, optimize, false);
    const tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/tests.zig"),
            .target = b.graph.host,
            .optimize = optimize,
            .code_model = .normal,
        }),
    });

    modules.addCommonImports(tests.root_module, common_modules);
    tests.root_module.error_tracing = true;

    const run_tests = b.addRunArtifact(tests);
    run_tests.has_side_effects = true;

    const tests_step = b.step("tests", "Run unit tests");
    tests_step.dependOn(&run_tests.step);
}
