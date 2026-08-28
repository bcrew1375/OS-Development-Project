const port_io = @import("port_io.zig");

const MiscellaneousOutputWritePort: u16 = 0x3C2;
const SequencerIndexPort: u16 = 0x3C4;
const SequencerDataPort: u16 = 0x3C5;
const CrtcIndexPort: u16 = 0x3D4;
const CrtcDataPort: u16 = 0x3D5;
const GraphicsControllerIndexPort: u16 = 0x3CE;
const GraphicsControllerDataPort: u16 = 0x3CF;
const AttributeControllerIndexPort: u16 = 0x3C0;
const AttributeControllerDataWritePort: u16 = 0x3C0;
const InputStatusOneReadPort: u16 = 0x3DA;

const EndAttributeControllerRegisterWrite: u8 = 0x20;

const RegisterSet = struct {
    miscellaneous_output: u8,
    sequencer: [5]u8,
    crtc: [25]u8,
    graphics_controller: [9]u8,
    attribute_controller: [21]u8,
};

const color_80x25_text_mode_registers = RegisterSet{
    .miscellaneous_output = 0x67,
    .sequencer = .{
        0x03,
        0x00,
        0x03,
        0x00,
        0x02,
    },
    .crtc = .{
        0x5F,
        0x4F,
        0x50,
        0x82,
        0x55,
        0x81,
        0xBF,
        0x1F,
        0x00,
        0x4F,
        0x0D,
        0x0E,
        0x00,
        0x00,
        0x00,
        0x00,
        0x9C,
        0x0E,
        0x8F,
        0x28,
        0x1F,
        0x96,
        0xB9,
        0xA3,
        0xFF,
    },
    .graphics_controller = .{
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        0x10,
        0x0E,
        0x00,
        0xFF,
    },
    .attribute_controller = .{
        0x00,
        0x01,
        0x02,
        0x03,
        0x04,
        0x05,
        0x14,
        0x07,
        0x38,
        0x39,
        0x3A,
        0x3B,
        0x3C,
        0x3D,
        0x3E,
        0x3F,
        0x0C,
        0x00,
        0x0F,
        0x08,
        0x00,
    },
};

pub fn initializeColorTextMode() void {
    writeRegisters(color_80x25_text_mode_registers);
}

fn writeRegisters(registers: RegisterSet) void {
    port_io.out8(MiscellaneousOutputWritePort, registers.miscellaneous_output);

    for (registers.sequencer, 0..) |value, index| {
        port_io.out8(SequencerIndexPort, @intCast(index));
        port_io.out8(SequencerDataPort, value);
    }

    unlockCrtcRegisters();
    for (registers.crtc, 0..) |value, index| {
        port_io.out8(CrtcIndexPort, @intCast(index));
        port_io.out8(CrtcDataPort, value);
    }

    for (registers.graphics_controller, 0..) |value, index| {
        port_io.out8(GraphicsControllerIndexPort, @intCast(index));
        port_io.out8(GraphicsControllerDataPort, value);
    }

    for (registers.attribute_controller, 0..) |value, index| {
        resetAttributeControllerFlipFlop();
        port_io.out8(AttributeControllerIndexPort, @intCast(index));
        port_io.out8(AttributeControllerDataWritePort, value);
    }

    resetAttributeControllerFlipFlop();
    port_io.out8(AttributeControllerIndexPort, EndAttributeControllerRegisterWrite);
}

fn unlockCrtcRegisters() void {
    port_io.out8(CrtcIndexPort, 0x03);
    port_io.out8(CrtcDataPort, port_io.in8(CrtcDataPort) | 0x80);

    port_io.out8(CrtcIndexPort, 0x11);
    port_io.out8(CrtcDataPort, port_io.in8(CrtcDataPort) & 0x7F);
}

fn resetAttributeControllerFlipFlop() void {
    _ = port_io.in8(InputStatusOneReadPort);
}