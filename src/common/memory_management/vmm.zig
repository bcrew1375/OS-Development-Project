const arch = @import("arch");

pub fn faultHandler(reason: arch.FaultReason) void {
    _ = reason;
}
