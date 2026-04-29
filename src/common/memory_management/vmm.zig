const arch = @import("arch");

pub fn faultHandler(reason: arch.FaultInfo) void {
    var virtual_address = reason.address;
    virtual_address += 1;
}
