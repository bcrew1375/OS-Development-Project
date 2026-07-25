const arch = @import("arch");
const kernel_common = @import("kernel_common");

const diagnostics = @import("diagnostics.zig");
const vectors = @import("vectors.zig");
pub const idt = @import("interrupt_descriptor_table.zig");
pub const pic = @import("pic.zig");
const keyboard = @import("../platform/io/keyboard.zig");

pub fn enableInterrupts() void {
    asm volatile (
        \\sti
    );
}

pub fn disableInterrupts() void {
    asm volatile (
        \\cli
    );
}

pub fn acknowledgeInterrupt(vector: usize) void {
    pic.sendEndOfInterrupt(vector);
}

pub fn interruptHandler(vector: usize, stack_pointer: usize) callconv(.c) void {
    const diagnostic = diagnostics.recordInterrupt(vector);
    if (diagnostic.print) {
        arch.platform.writer().print("Interrupt 0x{x}: ", .{vector}) catch {};
    }

    switch (vector) {
        vectors.divide_by_zero => {
            arch.platform.writer().writeAll("Divide by zero.\n") catch {};
        },
        vectors.debug_exception => {
            arch.platform.writer().writeAll("Debug exception.\n") catch {};
        },
        0x02...0x05 => {},
        vectors.invalid_opcode => {
            arch.platform.writer().writeAll("Invalid opcode.\n") catch {};
        },
        0x07 => {},
        vectors.double_fault => {
            arch.platform.writer().writeAll("Double fault.\n") catch {};
        },
        0x09 => {},
        vectors.invalid_tss => {
            arch.platform.writer().writeAll("Invalid TSS.\n") catch {};
        },
        0x0B => {},
        vectors.stack_segment_fault => {
            arch.platform.writer().writeAll("Stack segment fault.\n") catch {};
        },
        vectors.general_protection_fault => {
            // const stack_array: *[1]usize = @ptrFromInt(stack_pointer);
            // const error_code: usize = stack_array[0];
            // _ = error_code; // Suppress unused variable warning
            arch.platform.writer().writeAll("General protection fault.\n") catch {};
            arch.platform.writer().print(" Stack Index: 0x{x}\n", .{stack_pointer}) catch {};
        },
        vectors.page_fault => handlePageFault(stack_pointer, diagnostic),
        0x0F => {},
        0x10 => {},
        vectors.alignment_check => {
            arch.platform.writer().writeAll("Alignment check.\n") catch {};
        },
        0x12...0x1F => {},
        vectors.timer => {
            if (diagnostic.print) {
                arch.platform.writer().print("Timer ({d} ticks).\n", .{diagnostic.count}) catch {};
            }
        },
        vectors.keyboard => {
            if (diagnostic.print) {
                arch.platform.writer().writeAll("Keyboard pressed.\n") catch {};
            }
            keyboard.clearKeyboard();
        },
        0x22...0xFFFFFFFF => {},
    }

    if (diagnostic.print) {
        arch.platform.writer().print(" --- Stack Index: {x}\n", .{stack_pointer}) catch {};
    }

    acknowledgeInterrupt(vector);
}

fn handlePageFault(stack_pointer: usize, diagnostic: diagnostics.Decision) void {
    kernel_common.vmm.faultHandler(readPageFaultInfo(stack_pointer));
    if (diagnostic.print) {
        arch.platform.writer().writeAll("Page fault.\n") catch {};
    }
}

fn readPageFaultInfo(stack_pointer: usize) arch.FaultInfo {
    const virtual_address = asm volatile ("mov %%cr2, %[out]"
        : [out] "=r" (-> u32),
    );
    const stack_array: *[1]usize = @ptrFromInt(stack_pointer);
    const error_code: usize = stack_array[0];

    return .{
        .address = virtual_address,
        .present = (error_code & 0x1) != 0,
        .write = (error_code & 0x2) != 0,
        .user = (error_code & 0x4) != 0,
        // .reserved       = (error_code & 0x8)  != 0,
        .instruction_fetch = (error_code & 0x10) != 0,
        // .protection_key = (error_code & 0x20) != 0,
        // .shadow_stack   = (error_code & 0x40) != 0,
    };
}
