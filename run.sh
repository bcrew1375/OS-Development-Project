#!/bin/sh

zig build
qemu-system-i386 -s -S -hda ./build/bin/os.bin -D qemu.log -d in_asm,exec,int -cpu kvm64

