//! Common memory-management subsystems.

/// Physical frame allocator.
pub const physical_memory = @import("pmm.zig");
/// Virtual memory area and mapping manager.
pub const virtual_memory = @import("vmm.zig");
/// Boundary-tag heap allocator implementation.
pub const heap = @import("heap.zig");
/// Kernel global heap wrapper.
pub const kernel_heap = @import("kernel_heap.zig");
