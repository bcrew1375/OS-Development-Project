#!/bin/sh

zig build
qemu-system-x86_64 -s -hda ./build/bin/os.bin -D qemu.log -d in_asm,exec -cpu kvm64

