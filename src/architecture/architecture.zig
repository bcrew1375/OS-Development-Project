const builtin = @import("builtin");

pub const Arch = switch (builtin.cpu.arch) {
    .x86 => @import("x86/architecture.zig"),
    //.x86_64 => @import("x86_64/architecture.zig"),
    //.aarch64 => @import("aarch64/architecture.zig"),
    else => @compileError("unsupported architecture"),
};
