#!/bin/sh

gdb -ex "target remote :1234" \
    -ex "set architecture i386" \
    -ex "add-symbol-file ./build/kernelfull.o 0x100000" \
    #-ex "break *0x100000" \
    #-ex "break kernelMain" \
    -ex "continue"
