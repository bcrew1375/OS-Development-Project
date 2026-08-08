const std = @import("std");

pub const ElfLoadError = error{
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

const ELF_PROGRAM_HEADER_EXECUTABLE: u32 = 1;
const ELF_PROGRAM_HEADER_WRITABLE: u32 = 2;
const ELF_PROGRAM_HEADER_READABLE: u32 = 4;

pub const SegmentPermissions = struct {
    readable: bool,
    writeable: bool,
    executable: bool,
};

pub const LoadableSegment = struct {
    virtual_address: u64,
    memory_size: u64,
    file_offset: usize,
    file_size: usize,
    permissions: SegmentPermissions,
};

pub const LoadableImage = struct {
    entry_point: u64,
    virtual_start: u64,
    virtual_end: u64,
    segment_count: usize,
};

pub fn parseLoadableImage(image: []const u8, page_size: u64) ElfLoadError!LoadableImage {
    const elf_header = try readElfHeader(image);
    try validateElfHeader(elf_header);

    var image_start: u64 = std.math.maxInt(u64);
    var image_end: u64 = 0;
    var loadable_segment_count: usize = 0;

    for (0..elf_header.e_phnum) |program_header_index| {
        const program_header = try readProgramHeader(image, elf_header, program_header_index);
        if (program_header.p_type != std.elf.PT_LOAD) {
            continue;
        }

        try validateLoadableProgramHeader(image, program_header);

        const virtual_start = @as(u64, program_header.p_vaddr);
        const virtual_end = std.math.add(u64, virtual_start, program_header.p_memsz) catch return ElfLoadError.InvalidLoadSegment;

        image_start = @min(image_start, std.mem.alignBackward(u64, virtual_start, page_size));
        image_end = @max(image_end, std.mem.alignForward(u64, virtual_end, page_size));
        loadable_segment_count += 1;
    }

    if (loadable_segment_count == 0) return ElfLoadError.NoLoadableSegments;
    if (image_start >= image_end) return ElfLoadError.InvalidLoadSegment;

    return .{
        .entry_point = elf_header.e_entry,
        .virtual_start = image_start,
        .virtual_end = image_end,
        .segment_count = loadable_segment_count,
    };
}

pub fn getLoadableSegment(image: []const u8, loadable_segment_index: usize) ElfLoadError!LoadableSegment {
    const elf_header = try readElfHeader(image);
    try validateElfHeader(elf_header);

    var current_loadable_index: usize = 0;
    for (0..elf_header.e_phnum) |program_header_index| {
        const program_header = try readProgramHeader(image, elf_header, program_header_index);
        if (program_header.p_type != std.elf.PT_LOAD) {
            continue;
        }

        if (current_loadable_index == loadable_segment_index) {
            try validateLoadableProgramHeader(image, program_header);
            return loadableSegmentFromProgramHeader(program_header);
        }

        current_loadable_index += 1;
    }

    return ElfLoadError.InvalidLoadSegment;
}

fn validateElfHeader(elf_header: std.elf.Elf32_Ehdr) ElfLoadError!void {
    if (elf_header.e_ident[std.elf.EI_CLASS] != std.elf.ELFCLASS32) return ElfLoadError.UnsupportedElfClass;
    if (elf_header.e_ident[std.elf.EI_DATA] != std.elf.ELFDATA2LSB) return ElfLoadError.UnsupportedElfEndian;
    if (elf_header.e_ident[std.elf.EI_VERSION] != 1) return ElfLoadError.UnsupportedElfVersion;
    if (elf_header.e_type != std.elf.ET.EXEC) return ElfLoadError.UnsupportedElfType;
    if (elf_header.e_machine != std.elf.EM.@"386") return ElfLoadError.UnsupportedElfMachine;
    if (elf_header.e_phentsize != @sizeOf(std.elf.Elf32_Phdr)) return ElfLoadError.InvalidProgramHeaderTable;
}

fn readElfHeader(image: []const u8) ElfLoadError!std.elf.Elf32_Ehdr {
    if (image.len < @sizeOf(std.elf.Elf32_Ehdr)) return ElfLoadError.InvalidElfImage;

    const elf_header = std.mem.bytesToValue(std.elf.Elf32_Ehdr, image[0..@sizeOf(std.elf.Elf32_Ehdr)]);
    if (!std.mem.eql(u8, elf_header.e_ident[0..4], std.elf.MAGIC)) return ElfLoadError.InvalidElfImage;
    return elf_header;
}

fn readProgramHeader(image: []const u8, elf_header: std.elf.Elf32_Ehdr, program_header_index: usize) ElfLoadError!std.elf.Elf32_Phdr {
    const program_header_offset = @as(usize, elf_header.e_phoff);
    const program_header_table_size = std.math.mul(usize, @as(usize, elf_header.e_phnum), @sizeOf(std.elf.Elf32_Phdr)) catch return ElfLoadError.InvalidProgramHeaderTable;
    const program_header_table_end = std.math.add(usize, program_header_offset, program_header_table_size) catch return ElfLoadError.InvalidProgramHeaderTable;
    if (program_header_table_end > image.len) return ElfLoadError.InvalidProgramHeaderTable;

    if (program_header_index >= elf_header.e_phnum) return ElfLoadError.InvalidProgramHeaderTable;

    const current_program_header_offset = program_header_offset + program_header_index * @sizeOf(std.elf.Elf32_Phdr);
    return std.mem.bytesToValue(std.elf.Elf32_Phdr, image[current_program_header_offset..][0..@sizeOf(std.elf.Elf32_Phdr)]);
}

fn validateLoadableProgramHeader(image: []const u8, program_header: std.elf.Elf32_Phdr) ElfLoadError!void {
    if (program_header.p_memsz == 0) return ElfLoadError.EmptyLoadSegment;
    if (program_header.p_filesz > program_header.p_memsz) return ElfLoadError.InvalidLoadSegment;

    const file_offset = @as(usize, program_header.p_offset);
    const file_size = @as(usize, program_header.p_filesz);
    const file_end = std.math.add(usize, file_offset, file_size) catch return ElfLoadError.InvalidLoadSegment;
    if (file_end > image.len) return ElfLoadError.InvalidLoadSegment;
}

fn loadableSegmentFromProgramHeader(program_header: std.elf.Elf32_Phdr) LoadableSegment {
    return .{
        .virtual_address = program_header.p_vaddr,
        .memory_size = program_header.p_memsz,
        .file_offset = program_header.p_offset,
        .file_size = program_header.p_filesz,
        .permissions = .{
            .readable = (program_header.p_flags & ELF_PROGRAM_HEADER_READABLE) != 0,
            .writeable = (program_header.p_flags & ELF_PROGRAM_HEADER_WRITABLE) != 0,
            .executable = (program_header.p_flags & ELF_PROGRAM_HEADER_EXECUTABLE) != 0,
        },
    };
}
