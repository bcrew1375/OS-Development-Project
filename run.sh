#!/bin/sh

zig build
qemu-system-x86_64 -s -S -hda ./build/bin/os.bin
