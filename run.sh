#!/bin/sh

zig build
qemu-system-i386 \
-S \
-s \
-hda ./build/bin/os.bin \
-D qemu.log \
-d in_asm,exec,int \
-cpu kvm64 \
-daemonize \
-pidfile .qemu.pid \
