const arch = @import("arch");

pub fn faultHandler(reason: arch.FaultInfo) void {
    if (reason.present == false) {}
}
/// Defines the access rights for a specific virtual memory mapping.
pub const MemoryPermissions = enum {
    read_only,
    read_write,
    execute_only,
    read_execute,
};

/// Defines a range of virtual memory with specific attributes.
pub const VirtualMemoryArea = struct {
    start_address: u64,
    end_address: u64,
    physical_frame: usize,
    starting_virtual_address: u64,
    ending_virtual_address: u64,
    physical_frame_address: u64,
    permissions: MemoryPermissions,
};

/// Manages the virtual-to-physical mappings for a specific context.
pub const AddressSpace = struct {
    /// Architecture-specific representation of the page table hierarchy.
    page_table_root: arch.PageTableRoot,

    /// Maps a virtual page to a physical frame.
    pub fn map_page(
        self: *AddressSpace,
        virtual_address: u64,
        physical_address: u64,
        permissions: MemoryPermissions,
    ) !void {
        // Implementation will call architecture-specific paging logic.
        _ = self; _ = virtual_address; _ = physical_address; _ = permissions;
    }

    pub fn unmap_page(self: *AddressSpace, virtual_address: u64) !void {
        // Implementation will call architecture-specific paging logic.
        _ = self; _ = virtual_address;
    }2
};

/// Entry point for handling memory faults (e.g., page faults).
pub fn handle_page_fault(fault_information: arch.FaultInfo) void {
    if (fault_information.present == false) {
        // Logic for handling pages not currently mapped (demand paging).
    }
}
