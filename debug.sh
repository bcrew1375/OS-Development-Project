#!/bin/sh

gdb -ex "target remote :1234" \
    -ex "add-symbol-file ./build/kernelfull.o 0x100000" \
    -ex "break kernel_main" \
    -ex "continue"
