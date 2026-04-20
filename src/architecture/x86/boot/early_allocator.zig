const arch = @import("arch");

const MAX_RESERVATIONS = 128;

const ReservedMapEntry = struct {
    address: usize,
    size: usize,
};

const ReservedMap = struct {
    entries: [MAX_RESERVATIONS]ReservedMapEntry = undefined,
    length: usize = 0,
};

const EarlyAllocError = error{
    OutOfReservations,
    OutOfSpace,
};

var reservedMap linksection(".multiboot.data") = ReservedMap{};
var memoryMap: *arch.MemoryMap linksection(".multiboot.data") = undefined;

extern const _kernel_start: anyopaque;
extern const _kernel_end: anyopaque;

pub fn initialize() linksection(".multiboot.text") void {
    memoryMap = arch.mmu.getMemoryMap();

    const kernel_start_address = @intFromPtr(&_kernel_start);
    const kernel_end_address = @intFromPtr(&_kernel_end);

    for (memoryMap.entries[0..memoryMap.length]) |entry| {
        if (entry.region_type != arch.MemoryMapEntryType.AVAILABLE) {
            reserve(@truncate(entry.address), @truncate(entry.size));
        }
    }

    reserve(kernel_start_address, kernel_end_address - kernel_start_address);
}

pub fn allocate(needed_size: usize) linksection(".multiboot.text") *usize {
    for (memoryMap.entries[0..memoryMap.length]) |region_entry| {
        if (region_entry.region_type != arch.MemoryMapEntryType.AVAILABLE) {
            continue;
        }

        var current_start_address: usize = @truncate(region_entry.address);
        var current_end_address: usize = @truncate(region_entry.address + (needed_size - 1));

        const region_size = region_entry.size;

        if (region_size < needed_size) {
            continue;
        }

        const region_end_address: usize = @truncate(region_entry.address + (region_size - 1));

        while (current_end_address < region_end_address) {
            var overlapped: bool = false;

            for (reservedMap.entries[0..reservedMap.length]) |reserved_entry| {
                const reserved_start_address = reserved_entry.address;
                const reserved_end_address: usize = @truncate(reserved_entry.address + (reserved_entry.size - 1));

                // Does the candidate address overlap with an already reserved region?
                if (((current_start_address >= reserved_start_address) and (current_start_address <= reserved_end_address)) or
                    ((current_end_address >= reserved_start_address) and (current_end_address <= reserved_end_address)) or
                    ((current_start_address <= reserved_start_address) and (current_end_address >= reserved_end_address)))
                {
                    overlapped = true;

                    current_start_address = reserved_end_address + 1;
                    current_end_address = @truncate(current_start_address + (needed_size - 1));
                }
            }

            if (overlapped == false) {
                break;
            }
        }

        // Does the needed size still fit within the candidate region?
        if (current_end_address < region_end_address) {
            reserve(current_start_address, needed_size);
            return @ptrFromInt(current_start_address);
        }
    }

    arch.platform.writer.print("Early allocation failed with error {s}", .{@errorName(EarlyAllocError.OutOfSpace)}) catch {};
    arch.cpu.unrecoverableHalt();
}

fn reserve(address: usize, size: usize) linksection(".multiboot.text") void {
    if (reservedMap.length >= MAX_RESERVATIONS) {
        arch.platform.writer.print("Early allocation failed with error: {s}", .{@errorName(EarlyAllocError.OutOfReservations)}) catch {};
        arch.cpu.unrecoverableHalt();
    }

    reservedMap.entries[reservedMap.length].address = address;
    reservedMap.entries[reservedMap.length].size = size;

    reservedMap.length += 1;
}
