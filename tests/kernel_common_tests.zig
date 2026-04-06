const arch = @import("arch");

test "Terminal - print" {
    arch.platform.print("print test");
}

test "Terminal - printLog" {
    arch.platform.printLog("printLog test");
}
