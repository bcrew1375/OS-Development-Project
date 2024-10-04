pub fn in8(port: u16) u8 {
    var in_data: u8 = 0;

    asm volatile (
        \\in %[port], %al
        : [_] "={al}" (in_data),
        : [port] "{dx}" (port),
        : "eax", "dx", "memory"
    );

    return in_data;
}

pub fn in16(port: u16) u16 {
    var in_data: u16 = 0;

    asm (
        \\in %[port], %ax 
        : [_] "={ax}" (in_data),
        : [port] "{dx}" (port),
        : "ax", "dx", "memory"
    );

    return in_data;
}

pub fn out8(port: u16, out_data: u8) void {
    asm volatile (
        \\out %[out_data], %[port]
        :
        : [port] "{dx}" (port),
          [out_data] "{al}" (out_data),
        : "dx", "al", "memory"
    );
}

pub fn out16(port: u16, out_data: u16) void {
    asm volatile (
        \\out %[out_data], %[port]
        :
        : [port] "{dx}" (port),
          [out_data] "{ax}" (out_data),
        : "dx", "ax", "memory"
    );
}
