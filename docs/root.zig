//! Kernel public API documentation.

/// Stable user/kernel ABI definitions shared by the kernel and root process.
pub const abi = @import("abi");
/// Common architecture interface facade, backed by the mock implementation for docs.
pub const architecture = @import("arch");
/// Architecture-independent kernel subsystems.
pub const kernel_common = @import("kernel_common");
/// Shared helpers usable by kernel and userspace components.
pub const shared = @import("shared");
