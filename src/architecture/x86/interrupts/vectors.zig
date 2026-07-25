pub const divide_by_zero: usize = 0x00;
pub const debug_exception: usize = 0x01;
pub const invalid_opcode: usize = 0x06;
pub const double_fault: usize = 0x08;
pub const invalid_tss: usize = 0x0A;
pub const stack_segment_fault: usize = 0x0C;
pub const general_protection_fault: usize = 0x0D;
pub const page_fault: usize = 0x0E;
pub const alignment_check: usize = 0x11;

pub const first_hardware_interrupt: usize = 0x20;
pub const timer: usize = 0x20;
pub const keyboard: usize = 0x21;

pub const total: usize = 256;
