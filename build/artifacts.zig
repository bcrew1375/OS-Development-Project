const std = @import("std");

const configuration = @import("configuration.zig");
const modules = @import("modules.zig");

pub const KernelArtifacts = struct {
    kernel: *std.Build.Step.Compile,
    root_task: configuration.RootTaskArtifact,
};

pub fn addKernelAndRootTask(
    b: *std.Build,
    config: configuration.BuildConfig,
    optimize: std.builtin.OptimizeMode,
    root_task: configuration.RootTaskArtifact,
) KernelArtifacts {
    const common_modules = modules.createCommonModules(
        b,
        config.kernel_target,
        optimize,
        config.architecture == .x86_32,
    );

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/kernel.zig"),
            .target = config.kernel_target,
            .optimize = optimize,
            .code_model = config.kernel_code_model,
        }),
        .use_llvm = true,
        .use_lld = true,
    });
    modules.addCommonImports(kernel.root_module, common_modules);

    installArtifactForArchitecture(b, kernel, config.architecture, config.kernel_linker_script);
    installRootTaskForArchitecture(
        b,
        root_task,
        config.architecture,
    );

    return .{
        .kernel = kernel,
        .root_task = root_task,
    };
}

fn installArtifactForArchitecture(
    b: *std.Build,
    artifact: *std.Build.Step.Compile,
    architecture: configuration.Architecture,
    linker_script: []const u8,
) void {
    artifact.setLinkerScript(b.path(linker_script));
    const install_artifact = b.addInstallArtifact(artifact, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("{s}/bin", .{@tagName(architecture)}) } },
    });
    b.getInstallStep().dependOn(&install_artifact.step);
}

fn installRootTaskForArchitecture(
    b: *std.Build,
    root_task: configuration.RootTaskArtifact,
    architecture: configuration.Architecture,
) void {
    const install_root_task = b.addInstallFileWithDir(
        root_task.path,
        .{ .custom = b.fmt("{s}/bin", .{@tagName(architecture)}) },
        root_task.install_name,
    );
    b.getInstallStep().dependOn(&install_root_task.step);
}
