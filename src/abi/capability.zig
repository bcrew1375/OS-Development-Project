pub const CapabilityHandle = u32;
pub const INVALID_CAPABILITY: CapabilityHandle = 0;

pub const ObjectType = enum(u32) {
    null = 0,
    address_space = 1,
    memory_object = 2,
    _,
};

pub const Rights = packed struct(u32) {
    read: bool = false,
    write: bool = false,
    execute: bool = false,
    manage: bool = false,
    _reserved: u28 = 0,

    pub fn contains(self: Rights, required: Rights) bool {
        return (!required.read or self.read) and
            (!required.write or self.write) and
            (!required.execute or self.execute) and
            (!required.manage or self.manage);
    }
};
