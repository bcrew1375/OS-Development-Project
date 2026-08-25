// Modified from OS Dev: https://wiki.osdev.org/Zig_Bare_Bones
const std = @import("std");

const Architecture = enum {
    x86_32,
    x86_64,
};

const BuildConfig = struct {
    architecture: Architecture,
    kernel_target: std.Build.ResolvedTarget,
    root_process_target: std.Build.ResolvedTarget,
    kernel_linker_script: []const u8,
    root_process_linker_script: []const u8,
    kernel_code_model: std.builtin.CodeModel,
};

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const architecture = b.option(Architecture, "arch", "Target architecture") orelse .x86_64;
    const config = resolveBuildConfig(b, architecture);

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

    const arch = b.createModule(.{
        .root_source_file = b.path("src/architecture/architecture.zig"),
        .target = config.kernel_target,
        .optimize = optimize,
    });

    const kernel_common = b.createModule(.{
        .root_source_file = b.path("src/kernel_common.zig"),
        .target = config.kernel_target,
        .optimize = optimize,
    });

    const shared = b.createModule(.{
        .root_source_file = b.path("src/shared/main.zig"),
        .target = config.kernel_target,
        .optimize = optimize,
    });

    const abi = b.createModule(.{
        .root_source_file = b.path("src/abi/main.zig"),
        .target = config.kernel_target,
        .optimize = optimize,
    });

    const root_process_abi = b.createModule(.{
        .root_source_file = b.path("src/abi/main.zig"),
        .target = config.root_process_target,
        .optimize = optimize,
    });

    const root_process_shared = b.createModule(.{
        .root_source_file = b.path("src/shared/main.zig"),
        .target = config.root_process_target,
        .optimize = optimize,
    });

    const root_process = b.addExecutable(.{
        .name = "root_process.elf",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/root_process/src/main.zig"),
            .target = config.root_process_target,
            .optimize = optimize,
            .code_model = .normal,
        }),
        .use_llvm = true,
        .use_lld = true,
    });

    // arch modules use @import("arch") internally; provide a self-import.
    arch.addImport("arch", arch);
    arch.addImport("kernel_common", kernel_common);
    arch.addImport("abi", abi);

    kernel_common.addImport("arch", arch);
    kernel_common.addImport("abi", abi);

    kernel.root_module.addImport("arch", arch);
    kernel.root_module.addImport("kernel_common", kernel_common);
    kernel.root_module.addImport("shared", shared);
    kernel.root_module.addImport("abi", abi);

    root_process.root_module.addImport("abi", root_process_abi);
    root_process.root_module.addImport("shared", root_process_shared);

    const arch_test = b.createModule(.{
        .root_source_file = b.path("src/architecture/architecture.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    const kernel_common_test = b.createModule(.{
        .root_source_file = b.path("src/kernel_common.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    const abi_test = b.createModule(.{
        .root_source_file = b.path("src/abi/main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    const shared_test = b.createModule(.{
        .root_source_file = b.path("src/shared/main.zig"),
        .target = b.graph.host,
        .optimize = optimize,
    });

    const tests = b.addTest(.{
        .root_module = b.createModule(.{ .root_source_file = b.path("tests/tests.zig"), .target = b.graph.host, .optimize = optimize, .code_model = .normal }),
    });

    arch_test.addImport("arch", arch_test);
    arch_test.addImport("kernel_common", kernel_common_test);
    arch_test.addImport("abi", abi_test);

    kernel_common_test.addImport("arch", arch_test);
    kernel_common_test.addImport("abi", abi_test);

    tests.root_module.addImport("arch", arch_test);
    tests.root_module.addImport("kernel_common", kernel_common_test);
    tests.root_module.addImport("shared", shared_test);
    tests.root_module.addImport("abi", abi_test);

    tests.root_module.error_tracing = true;

    const run_tests = b.addRunArtifact(tests);
    run_tests.has_side_effects = true;

    const tests_step = b.step("tests", "Run unit tests");
    tests_step.dependOn(&run_tests.step);

    kernel.setLinkerScript(b.path(config.kernel_linker_script));
    const install_kernel = b.addInstallArtifact(kernel, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("{s}/bin", .{@tagName(config.architecture)}) } },
    });
    b.getInstallStep().dependOn(&install_kernel.step);

    root_process.setLinkerScript(b.path(config.root_process_linker_script));
    const install_root_process = b.addInstallArtifact(root_process, .{
        .dest_dir = .{ .override = .{ .custom = b.fmt("{s}/bin", .{@tagName(config.architecture)}) } },
    });
    b.getInstallStep().dependOn(&install_root_process.step);

    const run_step = b.step("run", "Run kernel with qemu");
    switch (config.architecture) {
        .x86_32 => run_step.dependOn(&createDirectKernelRunStep(b, kernel, root_process).step),
        .x86_64 => run_step.dependOn(&createLimineRunStep(b, kernel, root_process).step),
    }
}

fn resolveBuildConfig(b: *std.Build, architecture: Architecture) BuildConfig {
    const Target = std.Target.x86;

    return switch (architecture) {
        .x86_32 => .{
            .architecture = architecture,
            .kernel_target = b.resolveTargetQuery(.{
                .cpu_arch = .x86,
                .os_tag = .freestanding,
                .abi = .none,
                .cpu_features_add = Target.featureSet(&.{.soft_float}),
                .cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx }),
            }),
            .root_process_target = b.resolveTargetQuery(.{
                .cpu_arch = .x86,
                .os_tag = .freestanding,
                .abi = .none,
            }),
            .kernel_linker_script = "src/architecture/x86/32/linker.ld",
            .root_process_linker_script = "src/root_process/src/linker_x86_32.ld",
            .kernel_code_model = .default,
        },
        .x86_64 => .{
            .architecture = architecture,
            .kernel_target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
                .abi = .none,
                // We use software float because we are disabling all SIMD stuff.
                .cpu_features_add = Target.featureSet(&.{.soft_float}),
                // Disable SIMD in kernel code until context switching saves it.
                .cpu_features_sub = Target.featureSet(&.{ .avx, .avx2, .sse, .sse2, .mmx }),
            }),
            .root_process_target = b.resolveTargetQuery(.{
                .cpu_arch = .x86_64,
                .os_tag = .freestanding,
                .abi = .none,
            }),
            .kernel_linker_script = "src/architecture/x86/64/linker.ld",
            .root_process_linker_script = "src/root_process/src/linker_x86_64.ld",
            .kernel_code_model = .kernel,
        },
    };
}

fn createDirectKernelRunStep(
    b: *std.Build,
    kernel: *std.Build.Step.Compile,
    root_process: *std.Build.Step.Compile,
) *std.Build.Step.Run {
    const qemu_cmd = b.addSystemCommand(&directQemuArgs);

    qemu_cmd.addArg("-kernel");
    qemu_cmd.addFileArg(kernel.getEmittedBin());

    qemu_cmd.addArg("-initrd");
    qemu_cmd.addFileArg(root_process.getEmittedBin());

    qemu_cmd.step.dependOn(b.getInstallStep());
    return qemu_cmd;
}

fn createLimineRunStep(
    b: *std.Build,
    kernel: *std.Build.Step.Compile,
    root_process: *std.Build.Step.Compile,
) *std.Build.Step.Run {
    const make_iso_cmd = createLimineIsoStep(b, kernel, root_process);
    const iso = make_iso_cmd.addOutputFileArg("kernel-x86_64.iso");

    const qemu_cmd = b.addSystemCommand(&limineQemuArgs);
    qemu_cmd.addArg("-cdrom");
    qemu_cmd.addFileArg(iso);
    qemu_cmd.step.dependOn(&make_iso_cmd.step);

    return qemu_cmd;
}

fn createLimineIsoStep(
    b: *std.Build,
    kernel: *std.Build.Step.Compile,
    root_process: *std.Build.Step.Compile,
) *std.Build.Step.Run {
    const script =
        \\set -eu
        \\iso_root="$1"
        \\kernel="$2"
        \\root_process="$3"
        \\limine_conf="$4"
        \\output_iso="$5"
        \\limine_dir="/opt/limine"
        \\
        \\require_tool() {
        \\    if ! command -v "$1" >/dev/null 2>&1; then
        \\        echo "missing required tool: $1" >&2
        \\        echo "rebuild the devcontainer so Limine ISO tooling is installed" >&2
        \\        exit 1
        \\    fi
        \\}
        \\
        \\find_limine_file() {
        \\    found="$(find "$limine_dir" -name "$1" -type f -print -quit 2>/dev/null || true)"
        \\    if [ -z "$found" ]; then
        \\        echo "missing Limine file: $1 under $limine_dir" >&2
        \\        echo "rebuild the devcontainer so Limine is installed from the binary branch" >&2
        \\        exit 1
        \\    fi
        \\    printf '%s\n' "$found"
        \\}
        \\
        \\require_tool xorriso
        \\require_tool limine
        \\
        \\limine_bios_sys="$(find_limine_file limine-bios.sys)"
        \\limine_bios_cd="$(find_limine_file limine-bios-cd.bin)"
        \\limine_uefi_cd="$(find_limine_file limine-uefi-cd.bin)"
        \\limine_boot_x64="$(find_limine_file BOOTX64.EFI)"
        \\
        \\rm -rf "$iso_root"
        \\mkdir -p "$iso_root/boot" "$iso_root/EFI/BOOT"
        \\cp "$kernel" "$iso_root/boot/kernel.elf"
        \\cp "$root_process" "$iso_root/boot/root_process.elf"
        \\cp "$limine_conf" "$iso_root/boot/limine.conf"
        \\cp "$limine_bios_sys" "$iso_root/boot/limine-bios.sys"
        \\cp "$limine_bios_cd" "$iso_root/boot/limine-bios-cd.bin"
        \\cp "$limine_uefi_cd" "$iso_root/boot/limine-uefi-cd.bin"
        \\cp "$limine_boot_x64" "$iso_root/EFI/BOOT/BOOTX64.EFI"
        \\
        \\xorriso -as mkisofs \
        \\    -b boot/limine-bios-cd.bin \
        \\    -no-emul-boot \
        \\    -boot-load-size 4 \
        \\    -boot-info-table \
        \\    --efi-boot boot/limine-uefi-cd.bin \
        \\    -efi-boot-part \
        \\    --efi-boot-image \
        \\    --protective-msdos-label \
        \\    "$iso_root" \
        \\    -o "$output_iso"
        \\limine bios-install "$output_iso"
    ;

    const make_iso_cmd = b.addSystemCommand(&.{ "bash", "-c", script, "make-limine-iso" });
    make_iso_cmd.addArg(b.pathFromRoot(".zig-cache/limine-iso-root"));
    make_iso_cmd.addFileArg(kernel.getEmittedBin());
    make_iso_cmd.addFileArg(root_process.getEmittedBin());
    make_iso_cmd.addFileArg(b.path("src/architecture/x86/64/boot/limine/limine.conf"));

    return make_iso_cmd;
}

const directQemuArgs = [_][]const u8{
    // zig fmt: off
    "qemu-system-i386",
    "-vnc", "127.0.0.1:0",
    "-chardev", "file,id=serial0,path=serial.log",
    "-serial", "chardev:serial0",
    "-S",
    "-s",
    "-m", "4G",
    "-daemonize",
    "-pidfile", ".qemu.pid",
    "-M", "accel=tcg,smm=off",
    "-D", "qemu.log",
    "-d", "int,cpu_reset,guest_errors",
    "-no-reboot",
    "-no-shutdown",
    // zig fmt: on
};

const limineQemuArgs = [_][]const u8{
    // zig fmt: off
    "qemu-system-x86_64",
    "-vnc", "127.0.0.1:0",
    "-chardev", "file,id=serial0,path=serial.log",
    "-serial", "chardev:serial0",
    "-S",
    "-s",
    "-m", "4G",
    "-daemonize",
    "-pidfile", ".qemu.pid",
    "-M", "accel=tcg,smm=off",
    "-D", "qemu.log",
    "-d", "int,cpu_reset,guest_errors",
    "-no-reboot",
    "-no-shutdown",
    // zig fmt: on
};
