const arch = @import("arch");
const kernel_common = @import("kernel_common");
const std = @import("std");

const vmm = kernel_common.memory_management.virtual_memory;

const USER_STACK_START: u64 = 0x0080_0000;
const USER_STACK_END: u64 = USER_STACK_START + 0x0040_0000;

const ElfLoadError = error{
    RootProcessModuleMissing,
    InvalidBootModuleRange,
    InvalidElfImage,
    UnsupportedElfClass,
    UnsupportedElfEndian,
    UnsupportedElfVersion,
    UnsupportedElfType,
    UnsupportedElfMachine,
    InvalidProgramHeaderTable,
    InvalidLoadSegment,
    EmptyLoadSegment,
    NoLoadableSegments,
};

const LoadableImageRange = struct {
    start: u64,
    end: u64,
};

pub fn launchRootProcess(address_space: *vmm.AddressSpace) !noreturn {
    const userStackPermissions = vmm.MemoryPermissions{
        .readable = true,
        .writeable = true,
        .executable = false,
        .user_accessible = true,
    };

    const root_module = arch.boot.getBootModule(0) orelse return ElfLoadError.RootProcessModuleMissing;
    const entry_point = try loadRootProcessElf(address_space, root_module);

    try vmm.map(address_space, USER_STACK_START, USER_STACK_END, userStackPermissions);

    const userStackLastByte: *u8 = @ptrFromInt(USER_STACK_END - 1);
    userStackLastByte.* = 0;

    arch.cpu.enterUserMode(entry_point, @intCast(USER_STACK_END));
}

fn loadRootProcessElf(address_space: *vmm.AddressSpace, root_module: arch.BootModule) !usize {
    const image = getBootModuleBytes(root_module);
    const elf_header = try readElfHeader(image);

    try validateElfHeader(elf_header);

    const loadable_image_range = try findLoadableImageRange(image, elf_header);
    const userImagePermissions = vmm.MemoryPermissions{
        .readable = true,
        // The VMM currently enforces write permission before it lazily allocates
        // a page, so initial executable loading keeps the coalesced image VMA
        // writable. Later permission tightening should happen through VMA/page
        // splitting or a remap/mprotect-style operation.
        .writeable = true,
        .executable = true,
        .user_accessible = true,
    };

    try vmm.map(address_space, loadable_image_range.start, loadable_image_range.end, userImagePermissions);

    for (0..elf_header.e_phnum) |program_header_index| {
        const program_header = try readProgramHeader(image, elf_header, program_header_index);
        if (program_header.p_type != std.elf.PT_LOAD) {
            continue;
        }

        try copyProgramSegment(image, program_header);
    }

    return elf_header.e_entry;
}

fn validateElfHeader(elf_header: std.elf.Elf32_Ehdr) !void {
    if (elf_header.e_ident[std.elf.EI_CLASS] != std.elf.ELFCLASS32) return ElfLoadError.UnsupportedElfClass;
    if (elf_header.e_ident[std.elf.EI_DATA] != std.elf.ELFDATA2LSB) return ElfLoadError.UnsupportedElfEndian;
    if (elf_header.e_ident[std.elf.EI_VERSION] != 1) return ElfLoadError.UnsupportedElfVersion;
    if (elf_header.e_type != std.elf.ET.EXEC) return ElfLoadError.UnsupportedElfType;
    if (elf_header.e_machine != std.elf.EM.@"386") return ElfLoadError.UnsupportedElfMachine;
    if (elf_header.e_phentsize != @sizeOf(std.elf.Elf32_Phdr)) return ElfLoadError.InvalidProgramHeaderTable;
}

fn findLoadableImageRange(image: []const u8, elf_header: std.elf.Elf32_Ehdr) !LoadableImageRange {
    const page_size = @as(u64, @intCast(arch.mmu.getPageSize()));
    var image_start: u64 = std.math.maxInt(u64);
    var image_end: u64 = 0;
    var found_loadable_segment = false;

    for (0..elf_header.e_phnum) |program_header_index| {
        const program_header = try readProgramHeader(image, elf_header, program_header_index);
        if (program_header.p_type != std.elf.PT_LOAD) {
            continue;
        }

        if (program_header.p_memsz == 0) return ElfLoadError.EmptyLoadSegment;
        if (program_header.p_filesz > program_header.p_memsz) return ElfLoadError.InvalidLoadSegment;

        const file_offset = @as(usize, program_header.p_offset);
        const file_size = @as(usize, program_header.p_filesz);
        const file_end = try std.math.add(usize, file_offset, file_size);
        if (file_end > image.len) return ElfLoadError.InvalidLoadSegment;

        const virtual_start = @as(u64, program_header.p_vaddr);
        const virtual_end = try std.math.add(u64, virtual_start, program_header.p_memsz);
        image_start = @min(image_start, std.mem.alignBackward(u64, virtual_start, page_size));
        image_end = @max(image_end, std.mem.alignForward(u64, virtual_end, page_size));
        found_loadable_segment = true;
    }

    if (!found_loadable_segment) return ElfLoadError.NoLoadableSegments;
    if (image_start >= image_end) return ElfLoadError.InvalidLoadSegment;

    return .{
        .start = image_start,
        .end = image_end,
    };
}

fn readProgramHeader(image: []const u8, elf_header: std.elf.Elf32_Ehdr, program_header_index: usize) !std.elf.Elf32_Phdr {
    const program_header_offset = @as(usize, elf_header.e_phoff);
    const program_header_table_size = try std.math.mul(usize, @as(usize, elf_header.e_phnum), @sizeOf(std.elf.Elf32_Phdr));
    const program_header_table_end = try std.math.add(usize, program_header_offset, program_header_table_size);
    if (program_header_table_end > image.len) return ElfLoadError.InvalidProgramHeaderTable;

    if (program_header_index >= elf_header.e_phnum) return ElfLoadError.InvalidProgramHeaderTable;

    const current_program_header_offset = program_header_offset + program_header_index * @sizeOf(std.elf.Elf32_Phdr);
    return std.mem.bytesToValue(std.elf.Elf32_Phdr, image[current_program_header_offset..][0..@sizeOf(std.elf.Elf32_Phdr)]);
}

fn getBootModuleBytes(root_module: arch.BootModule) []const u8 {
    if (root_module.physical_start >= root_module.physical_end) {
        return &[_]u8{};
    }

    const module_size = root_module.physical_end - root_module.physical_start;
    const module_virtual_start = @as(usize, @intCast(arch.mmu.getDirectMapVirtualAddress())) + root_module.physical_start;
    return @as([*]const u8, @ptrFromInt(module_virtual_start))[0..module_size];
}

fn readElfHeader(image: []const u8) !std.elf.Elf32_Ehdr {
    if (image.len < @sizeOf(std.elf.Elf32_Ehdr)) return ElfLoadError.InvalidElfImage;

    const elf_header = std.mem.bytesToValue(std.elf.Elf32_Ehdr, image[0..@sizeOf(std.elf.Elf32_Ehdr)]);
    if (!std.mem.eql(u8, elf_header.e_ident[0..4], std.elf.MAGIC)) return ElfLoadError.InvalidElfImage;
    return elf_header;
}

fn copyProgramSegment(image: []const u8, program_header: std.elf.Elf32_Phdr) !void {
    if (program_header.p_memsz == 0) return ElfLoadError.EmptyLoadSegment;
    if (program_header.p_filesz > program_header.p_memsz) return ElfLoadError.InvalidLoadSegment;

    const file_offset = @as(usize, program_header.p_offset);
    const file_size = @as(usize, program_header.p_filesz);
    const memory_size = @as(usize, program_header.p_memsz);
    const file_end = try std.math.add(usize, file_offset, file_size);
    if (file_end > image.len) return ElfLoadError.InvalidLoadSegment;

    const virtual_start = @as(u64, program_header.p_vaddr);
    const memory: [*]u8 = @ptrFromInt(@as(usize, @intCast(virtual_start)));
    @memcpy(memory[0..file_size], image[file_offset..file_end]);
    @memset(memory[file_size..memory_size], 0);
}
