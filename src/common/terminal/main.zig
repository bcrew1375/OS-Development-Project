//! Architecture-independent terminal initialization facade.

const arch = @import("arch");

/// Terminal printing helpers.
pub const print = @import("print.zig");

/// Initializes the active architecture console backend.
pub fn initialize() void {
    arch.platform.initializeConsole();
}
