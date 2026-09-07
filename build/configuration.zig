const std = @import("std");

pub const Architecture = enum {
    x86_32,
    x86_64,
};

pub const Bootloader = enum {
    limine,
    multiboot,
};

pub const BuildConfig = struct {
    architecture: Architecture,
    bootloader: Bootloader,
    kernel_target: std.Build.ResolvedTarget,
    kernel_linker_script: []const u8,
    kernel_code_model: std.builtin.CodeModel,
};

pub const RootTaskArtifact = struct {
    path: std.Build.LazyPath,
    install_name: []const u8,
};

pub fn resolve(
    b: *std.Build,
    architecture: Architecture,
    requested_bootloader: Bootloader,
) BuildConfig {
    const Target = std.Target.x86;
    const bootloader = switch (architecture) {
        .x86_32 => requested_bootloader,
        .x86_64 => .limine,
    };

    return switch (architecture) {
        .x86_32 => .{
            .architecture = architecture,
            .bootloader = bootloader,
            .kernel_target = b.resolveTargetQuery(.{
                .cpu_arch = .x86,
                .os_tag = .freestanding,
                .abi = .none,
                .cpu_features_add = Target.featureSet(&.{.soft_float}),
                .cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx }),
            }),
            .kernel_linker_script = switch (bootloader) {
                .limine => "src/architecture/x86/32/linker_limine.ld",
                .multiboot => "src/architecture/x86/32/linker_multiboot.ld",
            },
            .kernel_code_model = .default,
        },
        .x86_64 => .{
            .architecture = architecture,
            .bootloader = bootloader,
            .kernel_target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
                .abi = .none,
                // We use software float because we are disabling all SIMD stuff.
                .cpu_features_add = Target.featureSet(&.{.soft_float}),
                // Disable SIMD in kernel code until context switching saves it.
                .cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx }),
            }),
            .kernel_linker_script = "src/architecture/x86/64/linker.ld",
            .kernel_code_model = .kernel,
        },
    };
}

pub fn resolveRootTaskArtifact(b: *std.Build, config: BuildConfig) RootTaskArtifact {
    const path = b.option(
        []const u8,
        "root-task",
        "Path to the externally built root task ELF artifact",
    ) orelse b.pathFromRoot(b.fmt(
        "OS-Root-Task/zig-out/{s}/bin/root_process.elf",
        .{@tagName(config.architecture)},
    ));

    return .{
        .path = .{ .cwd_relative = path },
        .install_name = "root_process.elf",
    };
}

pub fn limineConfigPath(architecture: Architecture) []const u8 {
    return switch (architecture) {
        .x86_32 => "src/architecture/x86/32/boot/limine/limine.conf",
        .x86_64 => "src/architecture/x86/64/boot/limine/limine.conf",
    };
}
