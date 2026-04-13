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

    // const kernel_path = kernel.getEmittedBin();
    // const qemu_cmd = b.addSystemCommand(&[_][]const u8{
    //     // zig fmt: off
    //     "qemu-system-i386",
    //     //"-chardev", "stdio,id=char0,mux=on,logfile=serial.log,signal=off",
    //     //"-serial", "chardev:char0", "-mon", "chardev=char0",
    //     //"-debugcon", "stdio",
    //     "-S",
    //     "-s",
    //     "-m", "1G",
    //     //"-daemonize",
    //     "-pidfile", ".qemu.pid",
    //     "-M",
    //     "accel=tcg,smm=off",
    //     "-D", "qemu.log",
    //     "-d", "int",
    //     //"-no-reboot",
    //     //"-no-shutdown",
    // });
    // // zig fmt: on
    // qemu_cmd.addArg("-kernel");
    // qemu_cmd.addFileArg(kernel_path);
    // qemu_cmd.step.dependOn(b.getInstallStep());

    // const run_step = b.step("run", "Run kernel with qemu");
    // run_step.dependOn(&qemu_cmd.step);

    //     qemu_cmd.addFileArg(kernel_path);
    //     qemu_cmd.step.dependOn(b.getInstallStep());

    const debug_step = b.step("debug", "Build and launch QEMU for debugging");
    debug_step.dependOn(b.getInstallStep());
    debug_step.makeFn = spawnQemu;
}

fn spawnQemu(step: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
    _ = options;

    const b = step.owner;
    const kernel_path = b.getInstallPath(.bin, "kernel.elf");

    var child = std.process.Child.init(&.{
        "qemu-system-i386",
        //     //"-chardev", "stdio,id=char0,mux=on,logfile=serial.log,signal=off",
        //     //"-serial", "chardev:char0", "-mon", "chardev=char0",
        //     //"-debugcon", "stdio",
        "-S",
        "-s",
        "-m",
        "1G",
        //     //"-daemonize",
        "-pidfile",
        ".qemu.pid",
        "-M",
        "accel=tcg,smm=off",
        "-D",
        "qemu.log",
        "-d",
        "int",
        "-no-reboot",
        "-no-shutdown",
        "-kernel",
        kernel_path,
    }, step.owner.allocator);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;
    try child.spawn();

    const addr = try std.net.Address.parseIp("127.0.0.1", 1234);
    var attempts: u32 = 0;
    while (attempts < 100) : (attempts += 1) {
        if (std.net.tcpConnectToAddress(addr)) |conn| {
            conn.close();
            return;
        } else |_| {
            std.Thread.sleep(100 * std.time.ns_per_ms);
        }
    }
    return error.QemuTimeout; //     //std.Thread.sleep(5000000000);
}
