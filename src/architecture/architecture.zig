pub const Arch = struct {
    cpu: Cpu = undefined,
    terminal: Terminal = undefined,
    keyboard: Keyboard = undefined,
    paging: Paging = undefined,
    interrupts: Interrupts = undefined,
    startup: Startup = undefined,

    pub const Cpu = struct {
        unrecoverableHalt: fn () noreturn,
        setupTimer: fn () noreturn,
    };

    pub const Terminal = struct {
        initialize: fn () void,
        print: fn ([]const u8) void,
        printColor: fn ([]const u8, u8) void,
    };

    pub const Keyboard = struct {
        clearKeyboard: fn () void,
    };

    pub const Paging = struct {
        initialize: fn () void,
        removeIdentityMapping: fn () void,
        getPhysicalAddress: fn (usize) usize,
    };

    pub const Interrupts = struct {
        initialize: fn () void,
        set: fn () void,
        enableInterrupts: fn () void,
        disableInterrupts: fn () void,
        acknowledgeInterrupt: fn () void,
    };

    pub const Startup = struct {
        finishStartup: fn () void,
    };
};

pub fn getArch() Arch {
    const arch: Arch = .{
        .cpu = @import("x86/architecture.zig").cpu,
        .terminal = @import("x86/architecture.zig").terminal,
        .keyboard = @import("x86/architecture.zig").keyboard,
        .paging = @import("x86/architecture.zig").paging,
        .interrupts = @import("x86/architecture.zig").interrupts,
        .startup = @import("x86/architecture.zig").startup,

        //.x86_64 => @import("architecture/x86_64/architecture.zig").arch,
        //.aarch64 => @import("architecture/aarch64/architecture.zig").arch,
    };

    return arch;
}
