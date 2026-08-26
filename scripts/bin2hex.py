#!/usr/bin/env python3
"""
bin2hex.py - Convert a raw binary memory image into two hex formats:
  1. Word-per-line (32-bit), for riscv_dfetch's imem (one instruction word per line)
  2. Line-packed (128-bit), for main_memory's backing_mem (4 words packed per line)

Usage: python3 bin2hex.py <input.bin> <output_words.hex> <output_lines.hex>
"""
import sys

def bin_to_word_hex(data: bytes, outfile: str):
    """One 32-bit hex word per line, little-endian byte order within each word."""
    with open(outfile, 'w') as f:
        for i in range(0, len(data), 4):
            word_bytes = data[i:i+4]
            word = int.from_bytes(word_bytes, byteorder='little')
            f.write(f"{word:08X}\n")

def bin_to_line_hex(data: bytes, outfile: str):
    """One 128-bit hex value per line, packing 4 consecutive 32-bit words.
    Word order within the 128-bit line: word0 is the LOWEST address, placed
    in the LEAST significant bits of the 128-bit value (matches how
    main_memory.sv indexes backing_mem[addr[MEM_DEPTH-1:4]] and expects
    addr[3:2] to select which 32-bit word within the 128-bit line)."""
    with open(outfile, 'w') as f:
        for i in range(0, len(data), 16):  # 16 bytes = 128 bits = 4 words
            chunk = data[i:i+16]
            # pad the final chunk if the binary isn't a multiple of 16 bytes
            while len(chunk) < 16:
                chunk += b'\x00'

            line_value = 0
            for word_idx in range(4):
                word_bytes = chunk[word_idx*4:(word_idx+1)*4]
                word = int.from_bytes(word_bytes, byteorder='little')
                # word0 (lowest address) goes in the lowest bits of the 128-bit line
                line_value |= (word << (word_idx * 32))

            f.write(f"{line_value:032X}\n")

def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <input.bin> <output_words.hex> <output_lines.hex>")
        sys.exit(1)

    infile, words_out, lines_out = sys.argv[1], sys.argv[2], sys.argv[3]

    with open(infile, 'rb') as f:
        data = f.read()

    # Pad to a multiple of 16 bytes (128-bit line alignment) up front,
    # so both outputs are generated from the same padded image.
    while len(data) % 16 != 0:
        data += b'\x00'

    bin_to_word_hex(data, words_out)
    bin_to_line_hex(data, lines_out)

    print(f"Wrote {words_out} ({len(data)//4} words)")
    print(f"Wrote {lines_out} ({len(data)//16} lines)")

if __name__ == "__main__":
    main()
