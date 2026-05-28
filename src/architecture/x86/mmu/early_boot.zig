const arch = @import("arch");
const multiboot = @import("../boot/main.zig");

const common = @import("common.zig");

const MultibootMemoryMapEntry = extern struct {
    size: u32,
    address: u64,
    length: u64,
    region_type: MultibootMemoryMapRegionTypes,
};

const MultibootMemoryMapRegionTypes = enum(u32) {
    AVAILABLE = 1,
    RESERVED = 2,
    ACPI_RECLAIMABLE = 3,
    ACPI_NVS = 4,
    BAD_MEMORY = 5,
    _,
};

var EarlyPageTableCounter: usize linksection(".multiboot.data") = 0;

var memoryMap: arch.MemoryMap linksection(".multiboot.data") = arch.MemoryMap{};

var maxAvailableAddress: u64 linksection(".multiboot.data") = 0;

pub fn initializePaging() linksection(".multiboot.text") !void {
    const available_ram = getMaxAvailableAddress();
    const direct_map_size = @min(getDirectMapMaxSize(), available_ram);

    const needed_page_tables = @as(usize, @truncate((direct_map_size +| common.PAGE_TABLE_REGION_SIZE -| 1) / common.PAGE_TABLE_REGION_SIZE));

    const directory_entries_allocation_size = @sizeOf(common.PageEntry) * common.ENTRIES_PER_DIRECTORY;
    var kernel_page_directory_entries: common.PageDirectory = @ptrCast(@alignCast(try arch.early_allocator.allocate(directory_entries_allocation_size, common.PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT)));

    const page_tables_allocation_size = needed_page_tables * @sizeOf(common.PageEntry) * common.ENTRIES_PER_TABLE;
    const direct_map_entries_ptr: *anyopaque = try arch.early_allocator.allocate(page_tables_allocation_size, common.PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT);
    var direct_map_entries = @as([*][common.ENTRIES_PER_TABLE]common.PageEntry, @ptrCast(@alignCast(direct_map_entries_ptr)))[0..needed_page_tables];

    for (0..needed_page_tables) |directory_index| {
        kernel_page_directory_entries[directory_index].address = @truncate(@intFromPtr(&direct_map_entries[directory_index]) >> 12);
        kernel_page_directory_entries[directory_index].present = true;
        kernel_page_directory_entries[directory_index].writeable = true;

        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].address = @truncate(@intFromPtr(&direct_map_entries[directory_index]) >> 12);
        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].present = true;
        kernel_page_directory_entries[common.HIGHER_HALF_INDEX + directory_index].writeable = true;

        for (0..common.ENTRIES_PER_TABLE) |table_index| {
            direct_map_entries[directory_index][table_index].address = @truncate(directory_index * common.PAGE_TABLE_REGION_SIZE + (table_index * common.PAGE_SIZE) >> 12);
            direct_map_entries[directory_index][table_index].present = true;
            direct_map_entries[directory_index][table_index].writeable = true;
        }
    }

    asm volatile (
        \\mov %[pageDirectoryAddress], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        :
        : [pageDirectoryAddress] "{ecx}" (kernel_page_directory_entries),
        : .{ .ecx = true, .memory = true });
}

pub fn readMultibootMemoryMap() linksection(".multiboot.text") void {
    var offset: usize = 0;

    for (0..arch.MAX_MEMORY_MAP_ENTRIES) |entry| {
        if (offset >= multiboot.multibootInfo.mmap_length) {
            break;
        }

        const map_entry: *MultibootMemoryMapEntry = @ptrFromInt(multiboot.multibootInfo.mmap_addr + offset);

        memoryMap.entries[entry].address = map_entry.address;
        memoryMap.entries[entry].size = map_entry.length;

        switch (map_entry.region_type) {
            MultibootMemoryMapRegionTypes.AVAILABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.AVAILABLE,
            MultibootMemoryMapRegionTypes.ACPI_RECLAIMABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RECLAIMABLE,
            else => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RESERVED,
        }

        memoryMap.length += 1;
        offset += map_entry.size + 4;
    }
}

pub fn getMemoryMap() linksection(".multiboot.text") *arch.MemoryMap {
    if (memoryMap.length == 0) {
        readMultibootMemoryMap();
    }

    if (memoryMap.length == 0) {
        @panic("Couldn't parse memory map!");
    }

    return &memoryMap;
}

pub fn getMaxAvailableAddress() linksection(".multiboot.text") u64 {
    if (memoryMap.length == 0) {
        _ = getMemoryMap();
    }

    if (maxAvailableAddress == 0) {
        for (memoryMap.entries[0..memoryMap.length]) |entry| {
            if (entry.region_type == arch.MemoryMapRegionType.AVAILABLE) {
                maxAvailableAddress = entry.address + entry.size;
            }
        }
    }

    return maxAvailableAddress;
}

pub fn getDirectMapVirtualAddress() linksection(".multiboot.text") u64 {
    return common.DIRECT_MAP_VIRTUAL_ADDRESS;
}

pub fn getDirectMapMaxSize() linksection(".multiboot.text") u64 {
    return common.DIRECT_MAP_SIZE;
}
