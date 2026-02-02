pub const Arch = struct {
    cpu: Cpu = undefined,
    console: Console = undefined,
    mmu: Mmu = undefined,
    interrupts: Interrupts = undefined,
    //devices: Devices = undefined,
    startup: Startup = undefined,

    pub const Cpu = struct {
        setupTimer: fn () void,
        unrecoverableHalt: fn () noreturn,
    };

    pub const Console = struct {
        pub const LogLevel = enum(u4) {
            errorText,
            warningText,
            noticeText,
            infoText,
            debugText,
        };

        initialize: fn () void,
        print: fn ([]const u8) void,
        printLog: fn ([]const u8, LogLevel) void,
    };

    pub const Mmu = struct {
        initialize: fn () void,
        removeIdentityMapping: fn () void,
        getPhysicalAddress: fn (usize) usize,
    };

    pub const Interrupts = struct {
        initialize: fn () void,
        set: fn (usize, usize, usize) void,
        enableInterrupts: fn () void,
        disableInterrupts: fn () void,
        acknowledgeInterrupt: fn () void,
    };

    // pub const Devices = struct {
    //     pub fn input() =
    // };

    pub const Startup = struct {
        finishStartup: fn () void,
    };
};

pub fn getArch() Arch {
    const builtin = @import("builtin");

    const arch: Arch = if (builtin.is_test) .{
        .cpu = @import("mock/cpu.zig").Cpu(),
        .console = @import("mock/console.zig").Console(),
        //.keyboard = @import("x86/architecture.zig").keyboard,
        .mmu = @import("x86/paging.zig").Mmu(),
        .interrupts = @import("mock/interrupts.zig").Interrupts(),
        .startup = @import("mock/startup.zig").Startup(),
    } else .{
        .cpu = @import("x86/cpu.zig").Cpu(),
        .console = @import("x86/console.zig").Console(),
        //.keyboard = @import("x86/architecture.zig").keyboard,
        .mmu = @import("x86/paging.zig").Mmu(),
        .interrupts = @import("x86/interrupts.zig").Interrupts(),
        .startup = @import("x86/startup.zig").Startup(),

        //.x86_64 => @import("architecture/x86_64/architecture.zig").arch,
        //.aarch64 => @import("architecture/aarch64/architecture.zig").arch,
    };

    return arch;
}
