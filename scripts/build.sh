#!/bin/bash
# build.sh - compile/link/convert bring-up programs (test / coremark) for Spike or RTL
#
# Usage: ./build.sh spike               -> builds test.c for Spike (ORIGIN=0x10000), interactive debug
#        ./build.sh rtl                 -> builds custom_c.c for RTL sim (ORIGIN=0x0), produces hex + disassembly
#        ./build.sh rtl-trace           -> builds custom_c.c, runs on Spike w/ commit log (ORIGIN=0x0, matches rtl mode)
#        ./build.sh coremark-rtl        -> builds CoreMark for RTL sim (ORIGIN=0x0), produces hex + disassembly
#        ./build.sh coremark-spike      -> builds CoreMark for Spike (ORIGIN=0x10000), commit-logged run
#
# Layout assumed:
#   sw/bringup/src/    - start.s, test.c (spike), custom_c.c (rtl), linker.ld, linker_rtl.ld
#   sw/bringup/build/  - all generated output lands here
#   scripts/           - this script + bin2hex.py + spike_format.py + diff_traces.py
#   COREMARK_DIR       - path to the cloned eembc/coremark repo (see below)

set -e

export PATH=$HOME/riscv/bin:$PATH

BRINGUP_DIR="/home/vatistas/hdl_rampup/sv-learning/sw/bringup"
SRC_DIR="$BRINGUP_DIR/src"
BUILD_DIR="$BRINGUP_DIR/build"
SCRIPT_DIR="$(dirname "$0")"

COREMARK_DIR="/home/vatistas/hdl_rampup/TOOLS/coremark"
COREMARK_ITERATIONS="${COREMARK_ITERATIONS:-300}"   # override: COREMARK_ITERATIONS=1000 ./build.sh coremark-rtl
COREMARK_TOTAL_DATA_SIZE="${COREMARK_TOTAL_DATA_SIZE:-}"  # override: COREMARK_TOTAL_DATA_SIZE=1200 ./build.sh coremark-rtl

TDS_FLAG=""
if [ -n "$COREMARK_TOTAL_DATA_SIZE" ]; then
    TDS_FLAG="-DTOTAL_DATA_SIZE=$COREMARK_TOTAL_DATA_SIZE"
fi

mkdir -p "$BUILD_DIR"

if [ "$1" == "spike" ]; then
    echo "=== Building for Spike (ORIGIN=0x10000) ==="
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -mno-relax -nostdlib -nostartfiles \
        -T "$SRC_DIR/linker.ld" \
        -o "$BUILD_DIR/test_spike.elf" \
        "$SRC_DIR/start.s" "$SRC_DIR/test.c"

    echo "=== Entry point ==="
    riscv32-unknown-elf-readelf -h "$BUILD_DIR/test_spike.elf" | grep Entry

    echo "=== Disassembly -> $BUILD_DIR/test_spike.dis ==="
    riscv32-unknown-elf-objdump -d "$BUILD_DIR/test_spike.elf" > "$BUILD_DIR/test_spike.dis"

    echo "=== Launching Spike (interactive debug mode) ==="
    spike --isa=rv32im_zicsr -m0x10000:0x10000 --pc=0x10000 -d -l "$BUILD_DIR/test_spike.elf" 2> spike_trace.log

elif [ "$1" == "rtl" ]; then
    echo "=== Building for RTL (ORIGIN=0x0) ==="
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -mno-relax -nostdlib -nostartfiles \
        -T "$SRC_DIR/linker_rtl.ld" \
        -o "$BUILD_DIR/custom_c.elf" \
        "$SRC_DIR/start.s" "$SRC_DIR/custom_c.c"

    echo "=== Entry point ==="
    riscv32-unknown-elf-readelf -h "$BUILD_DIR/custom_c.elf" | grep Entry

    echo "=== Disassembly -> $BUILD_DIR/custom_c.dis ==="
    riscv32-unknown-elf-objdump -d "$BUILD_DIR/custom_c.elf" > "$BUILD_DIR/custom_c.dis"

    echo "=== Converting to hex (word-per-line + 128-bit-packed) ==="
    riscv32-unknown-elf-objcopy -O binary "$BUILD_DIR/custom_c.elf" "$BUILD_DIR/custom_c.bin"
    python3 "$SCRIPT_DIR/bin2hex.py" \
        "$BUILD_DIR/custom_c.bin" \
        "$BUILD_DIR/custom_c_words.hex" \
        "$BUILD_DIR/custom_c_lines.hex"

    echo ""
    echo "Done. Outputs in $BUILD_DIR/:"
    echo "  custom_c.elf                      - linked ELF"
    echo "  custom_c.dis                       - disassembly"
    echo "  custom_c_words.hex     - word-per-line hex (for riscv_dfetch)"
    echo "  custom_c_lines.hex     - 128-bit-packed hex (for main_memory)"

    echo ""
    echo "=== Symbol table (for reference) ==="
    riscv32-unknown-elf-nm "$BUILD_DIR/custom_c.elf" | grep -E "_start|main|halt|marker"

elif [ "$1" == "rtl-trace" ]; then
    echo "=== Building custom_c.c for Spike (ORIGIN=0x10000) - lockstep reference trace ==="
    echo "    (RTL itself keeps running at ORIGIN=0x0 via 'rtl' mode - the diff script"
    echo "     normalizes for the address offset between the two, no RTL changes needed)"
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -mno-relax -nostdlib -nostartfiles \
        -T "$SRC_DIR/linker.ld" \
        -o "$BUILD_DIR/custom_c_spike.elf" \
        "$SRC_DIR/start.s" "$SRC_DIR/custom_c.c"

    echo "=== Running on Spike with commit logging (ORIGIN=0x10000) ==="
    timeout 10s spike --isa=rv32im_zicsr -m0x10000:0x10000 --pc=0x10000 -l "$BUILD_DIR/custom_c_spike.elf" 2> "$BUILD_DIR/spike_raw.log" || true

    echo "=== Extracting PC-only trace ==="
    python3 "$SCRIPT_DIR/spike_format.py" "$BUILD_DIR/spike_raw.log" "$BUILD_DIR/spike_pc_only.log"

    echo ""
    echo "Done. Outputs in $BUILD_DIR/:"
    echo "  custom_c_spike.elf     - Spike-target ELF (ORIGIN=0x10000)"
    echo "  spike_raw.log          - full Spike commit log"
    echo "  spike_pc_only.log      - PC-only trace (still at 0x10000 base)"
    echo ""
    echo "  Build+run the RTL side separately ('rtl' mode + your RTL simulator),"
    echo "  then diff (offset 0x10000 is the default, no need to pass it explicitly):"
    echo "    python3 scripts/diff_traces.py <rtl_trace.log> $BUILD_DIR/spike_pc_only.log"

elif [ "$1" == "coremark-rtl" ]; then
    echo "=== Building CoreMark for RTL (ORIGIN=0x0, ITERATIONS=$COREMARK_ITERATIONS) ==="
    [ -n "$TDS_FLAG" ] && echo "    TOTAL_DATA_SIZE override: $COREMARK_TOTAL_DATA_SIZE"
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -nostdlib -nostartfiles \
        -DFLAGS_STR="\"-march=rv32im_zicsr -mabi=ilp32\"" \
        -DITERATIONS="$COREMARK_ITERATIONS" \
        $TDS_FLAG \
        -DRTL_TARGET -DCOREMARK_TELEMETRY \
        -I. -I"$COREMARK_DIR" -I"$COREMARK_DIR/barebones" \
        -T "$SRC_DIR/linker_rtl.ld" \
        -o "$BUILD_DIR/coremark_rtl.elf" \
        "$SRC_DIR/start.s" \
        "$COREMARK_DIR"/core_main.c "$COREMARK_DIR"/core_list_join.c \
        "$COREMARK_DIR"/core_matrix.c "$COREMARK_DIR"/core_state.c "$COREMARK_DIR"/core_util.c \
        "$COREMARK_DIR"/barebones/core_portme.c

    echo "=== Entry point ==="
    riscv32-unknown-elf-readelf -h "$BUILD_DIR/coremark_rtl.elf" | grep Entry

    echo "=== Disassembly -> $BUILD_DIR/coremark_rtl.dis ==="
    riscv32-unknown-elf-objdump -d "$BUILD_DIR/coremark_rtl.elf" > "$BUILD_DIR/coremark_rtl.dis"

    echo "=== Converting to hex (word-per-line + 128-bit-packed) ==="
    riscv32-unknown-elf-objcopy -O binary "$BUILD_DIR/coremark_rtl.elf" "$BUILD_DIR/coremark_rtl.bin"
    python3 "$SCRIPT_DIR/bin2hex.py" \
        "$BUILD_DIR/coremark_rtl.bin" \
        "$BUILD_DIR/coremark_words.hex" \
        "$BUILD_DIR/coremark_lines.hex"

    echo ""
    echo "Done. Outputs in $BUILD_DIR/:"
    echo "  coremark_rtl.elf       - linked ELF"
    echo "  coremark_rtl.dis        - disassembly"
    echo "  coremark_words.hex      - word-per-line hex (for riscv_dfetch)"
    echo "  coremark_lines.hex      - 128-bit-packed hex (for main_memory)"

    echo ""
    echo "=== Key symbols (for reference) ==="
    riscv32-unknown-elf-nm "$BUILD_DIR/coremark_rtl.elf" | grep -E "_start|^[0-9a-f]+ [TtBb] main$|halt|_telemetry_start|_stack_top|_bss_end"

elif [ "$1" == "coremark-spike" ]; then
    echo "=== Building CoreMark for Spike (ORIGIN=0x10000, ITERATIONS=$COREMARK_ITERATIONS) ==="
    [ -n "$TDS_FLAG" ] && echo "    TOTAL_DATA_SIZE override: $COREMARK_TOTAL_DATA_SIZE"
    riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -mno-relax -nostdlib -nostartfiles \
        -DFLAGS_STR="\"-march=rv32im_zicsr -mabi=ilp32\"" \
        -DITERATIONS="$COREMARK_ITERATIONS" \
        $TDS_FLAG \
        -DRTL_TARGET -DCOREMARK_TELEMETRY \
        -I. -I"$COREMARK_DIR" -I"$COREMARK_DIR/barebones" \
        -T "$SRC_DIR/linker.ld" \
        -o "$BUILD_DIR/coremark_spike.elf" \
        "$SRC_DIR/start.s" \
        "$COREMARK_DIR"/core_main.c "$COREMARK_DIR"/core_list_join.c \
        "$COREMARK_DIR"/core_matrix.c "$COREMARK_DIR"/core_state.c "$COREMARK_DIR"/core_util.c \
        "$COREMARK_DIR"/barebones/core_portme.c

    echo "=== Entry point ==="
    riscv32-unknown-elf-readelf -h "$BUILD_DIR/coremark_spike.elf" | grep Entry

    echo "=== Disassembly -> $BUILD_DIR/coremark_spike.dis ==="
    riscv32-unknown-elf-objdump -d "$BUILD_DIR/coremark_spike.elf" > "$BUILD_DIR/coremark_spike.dis"

    echo "=== Launching Spike ==="
    timeout 20s spike --isa=rv32im_zicsr -m0x10000:0x10000 --pc=0x10000 "$BUILD_DIR/coremark_spike.elf" 2> "$BUILD_DIR/spike_raw.log" || true

    echo "=== Extracting PC-only trace ==="
    python3 "$SCRIPT_DIR/spike_format.py" "$BUILD_DIR/spike_raw.log" "$BUILD_DIR/spike_pc_only.log"

    echo ""
    echo "Done. Outputs in $BUILD_DIR/:"
    echo "  coremark_spike.elf     - Spike-target ELF (ORIGIN=0x10000)"
    echo "  spike_raw.log          - full Spike commit log"
    echo "  spike_pc_only.log      - PC-only trace (still at 0x10000 base)"
    echo ""
    echo "  Build+run the RTL side separately ('rtl' mode + your RTL simulator),"
    echo "  then diff (offset 0x10000 is the default, no need to pass it explicitly):"
    echo "    python3 scripts/diff_traces.py <rtl_trace.log> $BUILD_DIR/spike_pc_only.log"


else
    echo "Usage: $0 [spike|rtl|rtl-trace|coremark-rtl|coremark-spike]"
    echo "  Optional: COREMARK_ITERATIONS=N ./build.sh coremark-rtl"
    echo "  Optional: COREMARK_TOTAL_DATA_SIZE=N ./build.sh coremark-rtl"
    exit 1
fi
