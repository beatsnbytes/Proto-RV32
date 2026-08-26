#!/bin/bash
# build.sh - compile/link/convert the bring-up test program
#
# Usage: ./build.sh spike   -> builds for Spike (ORIGIN=0x10000), drops into interactive debug
#        ./build.sh rtl     -> builds for RTL sim (ORIGIN=0x0), produces hex + disassembly
#
# Layout assumed:
#   sw/bringup/src/    - start.s, test.c (spike), test_rtl.c (rtl), linker.ld, linker_rtl.ld
#   sw/bringup/build/  - all generated output lands here
#   scripts/           - this script + bin2hex.py

set -e

export PATH=$HOME/riscv/bin:$PATH

BRINGUP_DIR="/home/vatistas/hdl_rampup/sv-learning/sw/bringup"
SRC_DIR="$BRINGUP_DIR/src"
BUILD_DIR="$BRINGUP_DIR/build"
SCRIPT_DIR="$(dirname "$0")"

mkdir -p "$BUILD_DIR"

if [ "$1" == "spike" ]; then
    echo "=== Building for Spike (ORIGIN=0x10000) ==="
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles \
        -T "$SRC_DIR/linker.ld" \
        -o "$BUILD_DIR/test_spike.elf" \
        "$SRC_DIR/start.s" "$SRC_DIR/test.c"

    echo "=== Entry point ==="
    riscv32-unknown-elf-readelf -h "$BUILD_DIR/test_spike.elf" | grep Entry

    echo "=== Disassembly -> $BUILD_DIR/test_spike.dis ==="
    riscv32-unknown-elf-objdump -d "$BUILD_DIR/test_spike.elf" > "$BUILD_DIR/test_spike.dis"

    echo "=== Launching Spike (interactive debug mode) ==="
    spike --isa=rv32im_zicsr -m0x10000:0x4000 --pc=0x10000 -d "$BUILD_DIR/test_spike.elf"

elif [ "$1" == "rtl" ]; then
    echo "=== Building for RTL (ORIGIN=0x0) ==="
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles \
        -T "$SRC_DIR/linker_rtl.ld" \
        -o "$BUILD_DIR/test_rtl.elf" \
        "$SRC_DIR/start.s" "$SRC_DIR/test_rtl.c"

    echo "=== Entry point ==="
    riscv32-unknown-elf-readelf -h "$BUILD_DIR/test_rtl.elf" | grep Entry

    echo "=== Disassembly -> $BUILD_DIR/test_rtl.dis ==="
    riscv32-unknown-elf-objdump -d "$BUILD_DIR/test_rtl.elf" > "$BUILD_DIR/test_rtl.dis"

    echo "=== Converting to hex (word-per-line + 128-bit-packed) ==="
    riscv32-unknown-elf-objcopy -O binary "$BUILD_DIR/test_rtl.elf" "$BUILD_DIR/test_rtl.bin"
    python3 "$SCRIPT_DIR/bin2hex.py" \
        "$BUILD_DIR/test_rtl.bin" \
        "$BUILD_DIR/assembly_instruction_words.hex" \
        "$BUILD_DIR/assembly_instruction_lines.hex"

    echo ""
    echo "Done. Outputs in $BUILD_DIR/:"
    echo "  test_rtl.elf         - linked ELF"
    echo "  test_rtl.dis         - disassembly"
    echo "  assembly_instruction_words.hex   - word-per-line hex (for riscv_dfetch)"
    echo "  assembly_instruction_lines.hex   - 128-bit-packed hex (for main_memory)"

    echo ""
    echo "=== Symbol table (for reference) ==="
    riscv32-unknown-elf-nm "$BUILD_DIR/test_rtl.elf" | grep -E "_start|main|halt|marker"

else
    echo "Usage: $0 [spike|rtl]"
    exit 1
fi