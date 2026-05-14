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

var kernelPageTables: *[common.PAGE_TABLES_COUNT][common.ENTRIES_PER_TABLE]common.PageEntry linksection(".multiboot.data") = undefined;
var kernelPageDirectory: common.PageDirectory linksection(".multiboot.data") = undefined;

var EarlyPageTableCounter: usize linksection(".multiboot.data") = 0;

var memoryMap: arch.MemoryMap linksection(".multiboot.data") = arch.MemoryMap{};

var maxAvailableAddress: u64 = 0;

pub fn initializePaging() linksection(".multiboot.text") !void {
    var kernelPageDirectoryEntries: common.PageDirectory = @ptrCast(@alignCast(try arch.early_allocator.allocate(@sizeOf(common.PageEntry) * common.ENTRIES_PER_DIRECTORY, common.PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT)));
    var kernelPageTable0Entries: common.PageTable = @ptrCast(@alignCast(try arch.early_allocator.allocate(@sizeOf(common.PageEntry) * common.ENTRIES_PER_TABLE, common.PAGE_SIZE, arch.ReservedMapRegionType.PERSISTENT)));

    kernelPageDirectoryEntries[0].address = @truncate(@intFromPtr(kernelPageTable0Entries) >> 12);
    kernelPageDirectoryEntries[0].present = true;
    kernelPageDirectoryEntries[0].writeable = true;

    kernelPageDirectoryEntries[common.HIGHER_HALF_INDEX].address = @truncate(@intFromPtr(kernelPageTable0Entries) >> 12);
    kernelPageDirectoryEntries[common.HIGHER_HALF_INDEX].present = true;
    kernelPageDirectoryEntries[common.HIGHER_HALF_INDEX].writeable = true;

    // Recursive mapping setup.
    kernelPageDirectoryEntries[common.ENTRIES_PER_DIRECTORY - 1].address = @truncate(@intFromPtr(kernelPageDirectoryEntries) >> 12);
    kernelPageDirectoryEntries[common.ENTRIES_PER_DIRECTORY - 1].present = true;
    kernelPageDirectoryEntries[common.ENTRIES_PER_DIRECTORY - 1].writeable = true;

    // //Only map the first 4 MB.
    for (0..common.ENTRIES_PER_TABLE) |table_index| {
        kernelPageTable0Entries[table_index].address = @truncate((table_index * common.PAGE_SIZE) >> 12);
        kernelPageTable0Entries[table_index].present = true;
        kernelPageTable0Entries[table_index].writeable = true;
    }

    EarlyPageTableCounter += 1;

    asm volatile (
        \\mov %[pageDirectoryAddress], %eax
        \\mov %eax, %cr3
        \\mov %cr0, %eax
        \\or $0x80010000, %eax
        \\mov %eax, %cr0
        :
        : [pageDirectoryAddress] "{ecx}" (kernelPageDirectoryEntries),
        : .{ .ecx = true, .memory = true });

    kernelPageTables = @as(*[common.PAGE_TABLES_COUNT][common.ENTRIES_PER_TABLE]common.PageEntry, @ptrFromInt(common.PAGE_TABLES_BASE));
    kernelPageDirectory = kernelPageDirectoryEntries;
}

pub fn mapEarlyPageTable(allocation_start_address: usize, mapping_start_address: usize) linksection(".multiboot.text") void {
    kernelPageDirectory[EarlyPageTableCounter].address = @truncate(allocation_start_address >> 12);
    kernelPageDirectory[EarlyPageTableCounter].present = true;
    kernelPageDirectory[EarlyPageTableCounter].writeable = true;

    const page_table: common.PageTable = @ptrFromInt(allocation_start_address);

    for (0..common.ENTRIES_PER_TABLE) |table_index| {
        page_table[table_index].address = @truncate((mapping_start_address + (table_index * common.PAGE_SIZE)) >> 12);
        page_table[table_index].present = true;
        page_table[table_index].writeable = true;
    }

    asm volatile (
        \\mov %cr3, %eax
        \\mov %eax, %cr3
        ::: .{ .eax = true });

    EarlyPageTableCounter += 1;
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

    return &memoryMap;
}

pub fn getMaxAvailableAddress() linksection(".multiboot.text") u64 {
    if (maxAvailableAddress == 0) {
        for (memoryMap.entries[0..memoryMap.length]) |entry| {
            if (entry.region_type == arch.MemoryMapRegionType.AVAILABLE) {
                maxAvailableAddress = entry.address + entry.size;
            }
        }
    }

    return maxAvailableAddress;
}

pub fn removeIdentityMapping() void {
    kernelPageDirectory[0].address = 0;
    kernelPageDirectory[0].present = false;
    kernelPageDirectory[0].writeable = false;
    kernelPageDirectory[0].accessed = false;

    asm volatile (
        \\mov %cr3, %eax
        \\mov %eax, %cr3
    );
}
