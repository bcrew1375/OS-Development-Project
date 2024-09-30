const std = @import("std");
const fs = std.fs;

const ZIG_SOURCE_FILES = [_][]const u8{
    "./src/kernel.zig",
};

const OBJ_FILES = [_][]const u8{
    "./build/kernel.asm.o",
    "./build/kernel.zig.o",
};

pub fn build(b: *std.Build) void {
    // Define the boot sector binary target
    var boot_sector_bin = b.addSystemCommand(&[_][]const u8{
        "nasm",
        "-f",
        "bin",
        "./src/boot/boot-sector.asm",
        "-o",
        "./build/bin/boot-sector.bin",
    });
    //boot_sector_bin.setDescription("Assembling boot-sector.asm to boot-sector.bin");

    // Define the kernel object file target
    var kernel_asm_obj = b.addSystemCommand(&[_][]const u8{
        "nasm",
        "-f",
        "elf",
        "-g",
        "./src/boot/kernel.asm",
        "-o",
        "./build/kernel.asm.o",
    });

    var zig_obj = b.addSystemCommand(&[_][]const u8{
        "zig",
        "build-obj",
        "--emit-relocs",
        "-fstrip",
    } ++ ZIG_SOURCE_FILES ++ &[_][]const u8{
        "-O",
        "ReleaseSmall",
        "-femit-bin=./build/kernel.zig.o",
        "-target",
        "x86-freestanding",
    });

    // Define the kernel object file to binary
    var kernel_obj_to_bin = b.addSystemCommand(&[_][]const u8{
        "zig",
        "build-obj",
        "--emit-relocs",
        "-fstrip",
    } ++ OBJ_FILES ++ &[_][]const u8{
        "-O",
        "ReleaseSmall",
        "-femit-bin=./build/kernelfull.o",
        "-target",
        "x86-freestanding",
    });

    // Define the kernel binary target
    var kernel_link = b.addSystemCommand(&[_][]const u8{
        "zig",
        "build-exe",
        "./build/kernelfull.o",
        "--script",
        "./src/boot/linker.ld",
        "-fstrip",
        "-O",
        "ReleaseSmall",
        "-femit-bin=./build/bin/kernel.elf",
        "-target",
        "x86-freestanding",
    });
    //kernel_bin.setDescription("Linking kernel binary using custom linker script");

    var kernel_obj_copy = b.addSystemCommand(&[_][]const u8{
        "objcopy",
        //"-S",
        //"-g",
        "-O",
        "binary",
        "./build/bin/kernel.elf",
        "./build/bin/kernel.bin",
    });

    var remove_os_bin = b.addSystemCommand(&[_][]const u8{
        "rm",
        "-rf",
        "./build/bin/os.bin",
    });

    var inject_boot_sector = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "dd if=./build/bin/boot-sector.bin of=./build/bin/os.bin bs=512 seek=0 conv=notrunc",
    });

    var inject_kernel_sectors = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "dd if=./build/bin/kernel.bin of=./build/bin/os.bin bs=512 seek=1 conv=notrunc",
    });

    var create_disk_image = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "dd if=/dev/zero of=./build/bin/os.bin bs=1M count=1",
    });

    // Define the clean step
    var clean = b.addSystemCommand(&[_][]const u8{
        "rm",
        "-rf",
        "./build/bin/boot-sector.bin",
        "./build/bin/kernel.bin",
        "./build/bin/os.bin",
        "./build/kernel.asm.o",
        "./build/kernel.zig.o",
        "./build/kernel.zig.o.o",
        "./build/kernelfull.o",
    });

    // Ensure other build steps run in the correct order
    boot_sector_bin.step.dependOn(&clean.step);
    kernel_asm_obj.step.dependOn(&boot_sector_bin.step);
    zig_obj.step.dependOn(&kernel_asm_obj.step);
    kernel_obj_to_bin.step.dependOn(&zig_obj.step);
    kernel_link.step.dependOn(&kernel_obj_to_bin.step);
    kernel_obj_copy.step.dependOn(&kernel_link.step);
    remove_os_bin.step.dependOn(&kernel_obj_copy.step);
    create_disk_image.step.dependOn(&remove_os_bin.step);
    inject_boot_sector.step.dependOn(&create_disk_image.step);
    inject_kernel_sectors.step.dependOn(&inject_boot_sector.step);

    b.default_step.dependOn(&inject_kernel_sectors.step);
}
