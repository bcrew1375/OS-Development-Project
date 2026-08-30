const boot = @import("../main.zig");
const build_options = @import("build_options");

pub const protocol = @import("../../../common/boot/limine/protocol.zig");
const limine_requests = @import("../../../common/boot/limine/requests.zig");

comptime {
    if (!build_options.x86_32_multiboot) {
        @export(&_start, .{ .name = "_start" });
    }
}

pub fn _start() callconv(.c) noreturn {
    boot.kernelSetup();
}
