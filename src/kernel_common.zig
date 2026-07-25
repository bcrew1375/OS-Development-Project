pub const terminal = @import("common/terminal/main.zig");
pub const memory_management = @import("common/memory_management/main.zig");

// Compatibility aliases for existing code. New imports should prefer the
// hierarchical module names so call sites communicate their subsystem boundary.
pub const pmm = memory_management.physical_memory;
pub const vmm = memory_management.virtual_memory;
pub const kernel_heap = memory_management.kernel_heap;
pub const heap = memory_management.heap;
