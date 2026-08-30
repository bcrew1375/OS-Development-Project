const boot = @import("../main.zig");

pub const protocol = @import("../../../common/boot/limine/protocol.zig");
const limine_requests = @import("../../../common/boot/limine/requests.zig");

pub export fn _start() callconv(.c) noreturn {
    boot.kernelSetup();
}
