#!/bin/sh

zig build
qemu-system-i386 -s -hda ./build/bin/os.bin -D qemu.log -d in_asm,exec

