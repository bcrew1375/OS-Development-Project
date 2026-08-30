const build_options = @import("build_options");
const boot_text_section = if (build_options.x86_32_multiboot) ".multiboot.text" else ".text";
const boot_data_section = if (build_options.x86_32_multiboot) ".multiboot.data" else ".data";
const multiboot = @import("../boot/multiboot/main.zig");

const arch = @import("arch");

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

var memoryMap: arch.MemoryMap linksection(boot_data_section) = arch.MemoryMap{};
var maxAvailableAddress: u64 linksection(boot_data_section) = 0;

pub fn readMultibootMemoryMap() linksection(boot_text_section) void {
    var offset: usize = 0;

    for (0..arch.MAX_MEMORY_MAP_ENTRIES) |entry| {
        if (offset >= multiboot.multibootTable.mmap_length) {
            break;
        }

        const map_entry: *MultibootMemoryMapEntry = @ptrFromInt(multiboot.multibootTable.mmap_addr + offset);

        memoryMap.entries[entry].address = map_entry.address;
        memoryMap.entries[entry].size = map_entry.length;

        switch (map_entry.region_type) {
            MultibootMemoryMapRegionTypes.AVAILABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.AVAILABLE,
            MultibootMemoryMapRegionTypes.ACPI_RECLAIMABLE => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RECLAIMABLE,
            else => memoryMap.entries[entry].region_type = arch.MemoryMapRegionType.RESERVED,
        }

        memoryMap.length += 1;
        offset += map_entry.size + @sizeOf(u32);
    }
}

fn ensureMemoryMapLoaded() linksection(boot_text_section) void {
    if (memoryMap.length == 0) {
        readMultibootMemoryMap();
    }
}

pub fn getMemoryMap() linksection(boot_text_section) *arch.MemoryMap {
    ensureMemoryMapLoaded();

    if (memoryMap.length == 0) {
        @panic("Couldn't parse memory map!");
    }

    return &memoryMap;
}

pub fn getMaxAvailableAddress() linksection(boot_text_section) u64 {
    ensureMemoryMapLoaded();

    if (maxAvailableAddress == 0) {
        for (memoryMap.entries[0..memoryMap.length]) |entry| {
            if (entry.region_type == arch.MemoryMapRegionType.AVAILABLE) {
                maxAvailableAddress = @max(maxAvailableAddress, entry.address + entry.size);
            }
        }
    }

    return maxAvailableAddress;
}
