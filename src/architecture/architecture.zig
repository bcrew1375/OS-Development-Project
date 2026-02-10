pub const Arch = struct {
    cpu: Cpu = undefined,
    console: Console = undefined,
    paging: Paging = undefined,
    interrupts: Interrupts = undefined,
    // time: Time = undefined,
    // atomic: Atomic = undefined,
    startup: Startup = undefined,

    pub const Cpu = struct {
        /// Initialize CPU-specific features (FPU, SIMD, etc.)
        // initialize: fn () void,
        /// Halt CPU indefinitely (unrecoverable error)
        unrecoverableHalt: fn () noreturn,
        // /// Halt CPU until next interrupt (power saving)
        // haltUntilInterrupt: fn () void,
        // /// Get current CPU ID (for multiprocessor systems)
        // getCurrentCpuId: fn () usize,
        // /// Get total number of CPUs
        // getCpuCount: fn () usize,
        // /// Perform CPU-specific context switch
        // contextSwitch: fn (old_context: *anyopaque, new_context: *anyopaque) void,
        // /// Invalidate instruction cache (ARM/RISC-V specific, noop on x86)
        // invalidateInstructionCache: fn () void,
        // /// Memory barrier - ensure ordering
        // memoryBarrier: fn () void,
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
        // /// Check if console is ready for output (useful for early boot)
        // isReady: fn () bool,
    };

    pub const Paging = struct {
        // pub const PageSize = enum {
        //     small, // 4KB on x86/ARM, implementation-defined
        //     medium, // 2MB/4MB on x86, 64KB on ARM
        //     large, // 4MB/1GB on x86, 2MB on ARM
        // };

        // pub const PageFlags = packed struct {
        //     present: bool = false,
        //     writable: bool = false,
        //     user_accessible: bool = false,
        //     write_through: bool = false,
        //     cache_disabled: bool = false,
        //     accessed: bool = false,
        //     dirty: bool = false,
        //     executable: bool = false,
        //     global: bool = false,
        // };

        /// Initialize paging subsystem
        initialize: fn () void,
        /// Remove identity mapping (used in early boot)
        removeIdentityMapping: fn () void,
        /// Translate virtual to physical address
        getPhysicalAddress: fn (virt: usize) ?usize,
        // /// Map a page with specific flags
        // mapPage: fn (virt: usize, phys: usize, flags: PageFlags, size: PageSize) void,
        // /// Unmap a page
        // unmapPage: fn (virt: usize) void,
        // /// Flush TLB for specific address
        // flushTlb: fn (virt: usize) void,
        // /// Flush entire TLB
        // flushAllTlb: fn () void,
        // /// Switch page table (set new address space)
        // switchPageTable: fn (phys_addr: usize) void,
        // /// Get current page table physical address
        // getCurrentPageTable: fn () usize,
        // /// Get supported page sizes
        // getSupportedPageSizes: fn () []const PageSize,
    };

    pub const Interrupts = struct {
        // pub const InterruptFrame = struct {
        //     // Platform-specific saved register state
        //     // Should be a union or comptime-selected type
        //     data: *anyopaque,
        // };

        // pub const InterruptHandler = fn (frame: *InterruptFrame) void;

        /// Initialize interrupt controller (PIC/APIC/GIC/PLIC)
        initialize: fn () void,
        /// Register interrupt handler for vector
        set: fn (vector: usize, handler_address: usize, priority: usize) void,
        /// Enable interrupts globally
        enableInterrupts: fn () void,
        /// Disable interrupts globally
        disableInterrupts: fn () void,
        // /// Check if interrupts are enabled
        // areInterruptsEnabled: fn () bool,
        /// Acknowledge interrupt (send EOI to controller)
        acknowledgeInterrupt: fn (vector: usize) void,
        // /// Mask specific interrupt
        // maskInterrupt: fn (vector: usize) void,
        // /// Unmask specific interrupt
        // unmaskInterrupt: fn (vector: usize) void,
        // /// Trigger software interrupt / IPI
        // sendIpi: fn (cpu_id: usize, vector: usize) void,
    };

    pub const Time = struct {
        //     /// Nanoseconds type - u64 is fine here as it represents time, not addresses
        //     /// (585 years of nanoseconds fits in u64, sufficient for uptime)
        //     pub const Timestamp = u64;
        /// Set up architecture-specific timer
        setupTimer: fn (frequency_hz: usize) void,
        //     /// Get monotonic timestamp (nanoseconds since boot)
        //     getMonotonicTime: fn () Timestamp,
        //     /// Get wall clock time (Unix timestamp in nanoseconds)
        //     getWallTime: fn () Timestamp,
        //     /// Set wall clock time
        //     setWallTime: fn (timestamp_ns: Timestamp) void,
        //     /// Get timer frequency in Hz
        //     getTimerFrequency: fn () usize,
        //     /// Schedule timer interrupt (nanoseconds in the future)
        //     scheduleTimer: fn (delay_ns: Timestamp) void,
        // };

        // pub const Atomic = struct {
        //     /// Atomic compare-and-swap
        //     compareAndSwap: fn (ptr: *usize, expected: usize, new: usize) bool,
        //     /// Atomic fetch-and-add
        //     fetchAndAdd: fn (ptr: *usize, value: usize) usize,
        //     /// Atomic fetch-and-sub
        //     fetchAndSub: fn (ptr: *usize, value: usize) usize,
        //     /// Atomic exchange
        //     exchange: fn (ptr: *usize, new: usize) usize,
        //     /// Atomic load (with acquire semantics)
        //     load: fn (ptr: *const usize) usize,
        //     /// Atomic store (with release semantics)
        //     store: fn (ptr: *usize, value: usize) void,
    };

    pub const Startup = struct {
        // /// Early initialization (called first, before any subsystems)
        // earlyInit: fn () void,
        // /// Finish architecture-specific startup
        finishStartup: fn () void,
        // /// Jump to userspace for first process
        // jumpToUserspace: fn (entry: usize, stack: usize, arg: usize) noreturn,
    };
};

pub fn getArch() Arch {
    const builtin = @import("builtin");

    return if (builtin.is_test) .{
        .cpu = @import("mock/cpu.zig").Cpu(),
        .console = @import("mock/console.zig").Console(),
        .paging = @import("mock/paging.zig").Paging(),
        .interrupts = @import("mock/interrupts.zig").Interrupts(),
        // .time = @import("mock/time.zig").Time(),
        // .atomic = @import("mock/atomic.zig").Atomic(),
        .startup = @import("mock/startup.zig").Startup(),
    } else switch (builtin.cpu.arch) {
        .x86 => .{
            .cpu = @import("x86/cpu.zig").Cpu(),
            .console = @import("x86/console.zig").Console(),
            .paging = @import("x86/paging.zig").Paging(),
            .interrupts = @import("x86/interrupts.zig").Interrupts(),
            // .time = @import("x86/time.zig").Time(),
            // .atomic = @import("x86/atomic.zig").Atomic(),
            .startup = @import("x86/startup.zig").Startup(),
        },
        // .x86_64 => .{
        //     .cpu = @import("x86_64/cpu.zig").Cpu(),
        //     .console = @import("x86_64/console.zig").Console(),
        //     .paging = @import("x86_64/paging.zig").Paging(),
        //     .interrupts = @import("x86_64/interrupts.zig").Interrupts(),
        //     .time = @import("x86_64/time.zig").Time(),
        //     .atomic = @import("x86_64/atomic.zig").Atomic(),
        //     .startup = @import("x86_64/startup.zig").Startup(),
        // },
        // .aarch64 => .{
        //     .cpu = @import("aarch64/cpu.zig").Cpu(),
        //     .console = @import("aarch64/console.zig").Console(),
        //     .paging = @import("aarch64/paging.zig").Paging(),
        //     .interrupts = @import("aarch64/interrupts.zig").Interrupts(),
        //     .time = @import("aarch64/time.zig").Time(),
        //     .atomic = @import("aarch64/atomic.zig").Atomic(),
        //     .startup = @import("aarch64/startup.zig").Startup(),
        // },
        // .riscv64 => .{
        //     .cpu = @import("riscv64/cpu.zig").Cpu(),
        //     .console = @import("riscv64/console.zig").Console(),
        //     .paging = @import("riscv64/paging.zig").Paging(),
        //     .interrupts = @import("riscv64/interrupts.zig").Interrupts(),
        //     .time = @import("riscv64/time.zig").Time(),
        //     .atomic = @import("riscv64/atomic.zig").Atomic(),
        //     .startup = @import("riscv64/startup.zig").Startup(),
        // },
        else => @compileError("Unsupported architecture"),
    };
}
