export const _kernel_start: usize = 0;
export const _kernel_end: usize = 1024 * 1024;

test {
    _ = @import("pmm_tests.zig");
    _ = @import("kernel_common_tests.zig");
}
