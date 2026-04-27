// Modified from OS Dev: https://wiki.osdev.org/Zig_Bare_Bones
const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});

    const Target = std.Target.x86;
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
        .abi = .none,
        // We use software float because we are disabling all SIMD stuff
        .cpu_features_add = Target.featureSet(&.{.soft_float}),
        // Disable all SIMD related stuff because SIMD are problematic in kernel
        .cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx }),
    });

    const kernel = b.addExecutable(.{
        .name = "kernel.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path(b.pathJoin(&.{"src/kernel.zig"})),
            .target = target,
            .optimize = optimize,
            .code_model = .kernel,
        }),
    });

    const arch = b.createModule(.{
        .root_source_file = b.path("src/architecture/architecture.zig"),
        .target = target,
        .optimize = optimize,
    });

    arch.addImport("arch", arch);

    const kernel_common = b.createModule(.{
        .root_source_file = b.path("src/kernel_common.zig"),
        .target = target,
        .optimize = optimize,
    });

    kernel_common.addImport("arch", arch);
    kernel_common.addImport("kernel_common", kernel_common);

    kernel.root_module.addImport("arch", arch);
    kernel.root_module.addImport("kernel_common", kernel_common);

    const arch_test = b.createModule(.{
        .root_source_file = b.path("src/architecture/architecture.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    arch_test.addImport("arch", arch_test);

    const kernel_common_test = b.createModule(.{
        .root_source_file = b.path("src/kernel_common.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    kernel_common_test.addImport("arch", arch_test);
    kernel_common_test.addImport("kernel_common", kernel_common_test);

    const tests = b.addTest(.{
        .root_module = b.createModule(.{ .root_source_file = b.path("tests/tests.zig"), .target = b.graph.host, .optimize = optimize, .code_model = .normal }),
    });

    tests.root_module.addImport("arch", arch_test);
    tests.root_module.addImport("kernel_common", kernel_common_test);

    tests.root_module.error_tracing = true;

    const run_tests = b.addRunArtifact(tests);

    run_tests.has_side_effects = true;

    const tests_step = b.step("tests", "Run unit tests");
    tests_step.dependOn(&run_tests.step);

    kernel.setLinkerScript(b.path(b.pathJoin(&.{"src/linker.ld"})));
    b.installArtifact(kernel);

    const qemu_cmd = b.addSystemCommand(&[_][]const u8{
        // zig fmt: off
        "qemu-system-i386",
        // "-serial", "serial.log",
        // "-chardev", "stdio,id=char0,mux=on,logfile=serial.log,signal=off",
        // "-serial", "chardev:char0", "-mon", "chardev=char0",
        // "-debugcon", "stdio",
        "-chardev","file,id=serial0,path=serial.log",
        "-serial","chardev:serial0",
        "-S",
        "-s",
        "-m", "4G",
        "-daemonize",
        "-pidfile", ".qemu.pid",
        "-M",
        "accel=tcg,smm=off",
        "-D", "qemu.log",
        "-d", "int,cpu_reset,guest_errors",
        "-no-reboot",
        "-no-shutdown",
    });
    // zig fmt: on
    qemu_cmd.addArg("-kernel");
    const kernel_path = kernel.getEmittedBin();
    qemu_cmd.addFileArg(kernel_path);
    qemu_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run kernel with qemu");
    run_step.dependOn(&qemu_cmd.step);
}
