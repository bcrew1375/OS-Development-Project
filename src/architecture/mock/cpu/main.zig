pub fn unrecoverableHalt() noreturn {
    while (true) {}
}

pub fn enterUserMode(entry_point: usize, stack_top: usize, argument0: usize) noreturn {
    _ = argument0;
    _ = entry_point;
    _ = stack_top;
    @panic("mock architecture cannot enter user mode");
}
