const boot = @import("../main.zig");

pub const protocol = @import("protocol.zig");
pub const requests = @import("requests.zig");

pub export fn _start() callconv(.c) noreturn {
    boot.kernelSetup();
}
