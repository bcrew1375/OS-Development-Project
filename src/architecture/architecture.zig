const builtin = @import("builtin");

pub const impl = if (builtin.is_test)
    @import("mock/arch.zig")
else switch (builtin.cpu.arch) {
    //.x86_64 => @import("x86_64/impl.zig"),
    .x86 => @import("x86/arch.zig"),
    //.aarch64 => @import("aarch64/impl.zig"),
    //.riscv64 => @import("riscv64/impl.zig"),
    else => @compileError("unsupported architecture: " ++
        @tagName(builtin.cpu.arch)),
};

pub const boot = impl.boot;
pub const cpu = impl.cpu;
pub const interrupts = impl.interrupts;
pub const mmu = impl.mmu;
pub const platform = impl.platform;

pub const LogLevels = enum(u4) {
    errorText,
    warningText,
    noticeText,
    infoText,
    debugText,
};

pub fn validateImpl(comptime T: type) void {
    comptime {
        // cpu
        assertFn(T.cpu, "unrecoverableHalt", fn () noreturn);

        // mmu
        assertFn(T.mmu, "initialize", fn () callconv(.c) void);
        assertFn(T.mmu, "removeIdentityMapping", fn () void);
        assertFn(T.mmu, "getPhysicalAddress", fn (virtualAddress: usize) ?usize);

        // interrupts
        assertFn(T.interrupts, "initialize", fn () void);
        assertFn(T.interrupts, "set", fn (interruptVector: usize, address: usize, typeAttribute: usize) void);
        assertFn(T.interrupts, "enableInterrupts", fn () void);
        assertFn(T.interrupts, "disableInterrupts", fn () void);
        assertFn(T.interrupts, "acknowledgeInterrupt", fn (vector: usize) void);

        // platform
        assertFn(T.platform, "initializeTimer", fn (frequency: usize) void);
        assertFn(T.platform, "initializeConsole", fn () void);
        assertFn(T.platform, "print", fn (string: []const u8) void);
        assertFn(T.platform, "printLog", fn (string: []const u8, logLevel: LogLevels) void);
        // boot
        assertFn(T.boot, "finishBoot", fn () void);
    }
}

fn assertFn(comptime T: type, comptime functionName: []const u8, comptime signature: type) void {
    if (!@hasDecl(T, functionName))
        @compileError(@typeName(T) ++ " is missing '" ++ functionName ++ "'");
    if (@TypeOf(@field(T, functionName)) != signature)
        @compileError(@typeName(T) ++ "." ++ functionName ++ " has type: " ++ @typeName(@TypeOf(@field(T, functionName))) ++ ", expected type: " ++ @typeName(signature));
}
