const std = @import("std");

const configuration = @import("configuration.zig");

pub fn addStep(
    b: *std.Build,
    config: configuration.BuildConfig,
    kernel: *std.Build.Step.Compile,
    root_task: configuration.RootTaskArtifact,
) void {
    const run_step = b.step("run", "Run kernel with qemu");
    const run_command = switch (config.bootloader) {
        .multiboot => createDirectKernelRunStep(b, kernel, root_task),
        .limine => createLimineRunStep(b, config, kernel, root_task),
    };

    run_command.step.dependOn(b.getInstallStep());
    run_step.dependOn(&run_command.step);
}

fn createDirectKernelRunStep(
    b: *std.Build,
    kernel: *std.Build.Step.Compile,
    root_task: configuration.RootTaskArtifact,
) *std.Build.Step.Run {
    const qemu_cmd = b.addSystemCommand(&direct_qemu_args);

    qemu_cmd.addArg("-kernel");
    qemu_cmd.addFileArg(kernel.getEmittedBin());

    qemu_cmd.addArg("-initrd");
    qemu_cmd.addFileArg(root_task.path);

    return qemu_cmd;
}

fn createLimineRunStep(
    b: *std.Build,
    config: configuration.BuildConfig,
    kernel: *std.Build.Step.Compile,
    root_task: configuration.RootTaskArtifact,
) *std.Build.Step.Run {
    const make_iso_cmd = createLimineIsoStep(b, config, kernel, root_task);
    const iso = make_iso_cmd.addOutputFileArg(
        b.fmt("kernel-{s}.iso", .{@tagName(config.architecture)}),
    );

    const qemu_cmd = b.addSystemCommand(limineQemuArgs(config.architecture));
    qemu_cmd.addArg("-cdrom");
    qemu_cmd.addFileArg(iso);
    qemu_cmd.step.dependOn(&make_iso_cmd.step);

    return qemu_cmd;
}

fn createLimineIsoStep(
    b: *std.Build,
    config: configuration.BuildConfig,
    kernel: *std.Build.Step.Compile,
    root_task: configuration.RootTaskArtifact,
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
        \\
        \\rm -rf "$iso_root"
        \\mkdir -p "$iso_root/boot"
        \\cp "$kernel" "$iso_root/boot/kernel.elf"
        \\cp "$root_process" "$iso_root/boot/root_process.elf"
        \\cp "$limine_conf" "$iso_root/boot/limine.conf"
        \\cp "$limine_bios_sys" "$iso_root/boot/limine-bios.sys"
        \\cp "$limine_bios_cd" "$iso_root/boot/limine-bios-cd.bin"
        \\
        \\xorriso -as mkisofs \
        \\    -b boot/limine-bios-cd.bin \
        \\    -no-emul-boot \
        \\    -boot-load-size 4 \
        \\    -boot-info-table \
        \\    "$iso_root" \
        \\    -o "$output_iso"
        \\limine bios-install "$output_iso"
    ;

    const make_iso_cmd = b.addSystemCommand(&.{ "bash", "-c", script, "make-limine-iso" });
    make_iso_cmd.has_side_effects = true;
    make_iso_cmd.addArg(b.pathFromRoot(".zig-cache/limine-iso-root"));
    make_iso_cmd.addFileArg(kernel.getEmittedBin());
    make_iso_cmd.addFileArg(root_task.path);
    make_iso_cmd.addFileArg(b.path(configuration.limineConfigPath(config.architecture)));

    return make_iso_cmd;
}

const direct_qemu_args = [_][]const u8{
    // zig fmt: off
    "qemu-system-i386",
    "-vnc", "127.0.0.1:0",
    "-chardev", "file,id=serial0,path=serial.log",
    "-serial", "chardev:serial0",
    "-s",
    "-m", "4G",
    "-daemonize",
    "-pidfile", ".qemu.pid",
    "-M", "pc,accel=tcg,smm=off",
    "-D", "qemu.log",
    "-d", "int,cpu_reset,guest_errors",
    "-no-reboot",
    "-no-shutdown",
    // zig fmt: on
};

fn limineQemuArgs(architecture: configuration.Architecture) []const []const u8 {
    return switch (architecture) {
        .x86_32 => &limine_qemu_i386_args,
        .x86_64 => &limine_qemu_x86_64_args,
    };
}

const limine_qemu_i386_args = [_][]const u8{
    // zig fmt: off
    "qemu-system-i386",
    "-vga", "std",
    "-boot", "d",
    "-vnc", "127.0.0.1:0",
    "-chardev", "file,id=serial0,path=serial.log",
    "-serial", "chardev:serial0",
    "-s",
    "-m", "4G",
    "-daemonize",
    "-pidfile", ".qemu.pid",
    "-M", "pc,accel=tcg,smm=off",
    "-D", "qemu.log",
    "-d", "int,cpu_reset,guest_errors",
    "-no-reboot",
    "-no-shutdown",
    // zig fmt: on
};

const limine_qemu_x86_64_args = [_][]const u8{
    // zig fmt: off
    "qemu-system-x86_64",
    "-vga", "std",
    "-boot", "d",
    "-vnc", "127.0.0.1:0",
    "-chardev", "file,id=serial0,path=serial.log",
    "-serial", "chardev:serial0",
    "-s",
    "-m", "4G",
    "-daemonize",
    "-pidfile", ".qemu.pid",
    "-M", "pc,accel=tcg,smm=off",
    "-D", "qemu.log",
    "-d", "int,cpu_reset,guest_errors",
    "-no-reboot",
    "-no-shutdown",
    // zig fmt: on
};