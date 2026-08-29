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

// Field names deliberately mirror the multiboot specification's own
// SCREAMING_CASE constants rather than Zig's usual PascalCase enum
// convention. This is the same tradeoff the kernel makes with types
// like `__u32` at a userspace-facing ABI boundary: matching the
// external spec's vocabulary here is more valuable than internal
// naming consistency, since anyone cross-referencing this against the
// multiboot spec document benefits from the names matching exactly.
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
        // Per the multiboot spec, `map_entry.size` is the size of the
        // entry *excluding* the `size` field itself, so the field's own
        // width (a u32) has to be added to get to the next entry.
        offset += map_entry.size + @sizeOf(u32);
    }
}

/// Centralizes the lazy-load check that both `getMemoryMap` and
/// `getMaxAvailableAddress` previously duplicated independently. One
/// place now owns "has the map been read yet" - if that condition
/// ever needs to change (e.g. to a real `bool` flag instead of
/// `length == 0`), it changes in exactly one place instead of two.
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
