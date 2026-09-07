const std = @import("std");

const modules = @import("modules.zig");

pub fn addSteps(b: *std.Build, optimize: std.builtin.OptimizeMode) void {
    const common_modules = modules.createCommonModules(b, b.graph.host, optimize, false);
    const docs = b.addObject(.{
        .name = "public_api",
        .root_module = b.createModule(.{
            .root_source_file = b.path("docs/root.zig"),
            .target = b.graph.host,
            .optimize = optimize,
            .code_model = .normal,
        }),
    });

    modules.addCommonImports(docs.root_module, common_modules);

    const install_docs = b.addInstallDirectory(.{
        .source_dir = docs.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });

    const docs_step = b.step("docs", "Generate common API documentation");
    docs_step.dependOn(&install_docs.step);

    const serve_docs = b.addSystemCommand(&.{
        "python3",
        b.pathFromRoot("scripts/serve_docs.py"),
        b.pathFromRoot("zig-out/docs"),
        "--bind",
        "0.0.0.0",
        "--port",
        "8765",
    });
    serve_docs.has_side_effects = true;
    serve_docs.step.dependOn(docs_step);

    const serve_docs_step = b.step(
        "serve-docs",
        "Serve generated documentation at http://127.0.0.1:8765",
    );
    serve_docs_step.dependOn(&serve_docs.step);
}
