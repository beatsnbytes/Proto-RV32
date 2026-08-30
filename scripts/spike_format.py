#!/usr/bin/env python3
"""
spike_format.py - extract just the PC column from Spike's -l commit log,
formatted to match the RTL trace (one lowercase hex PC per line, no '0x' prefix).

Usage: python3 spike_format.py <spike_raw_log> <output_file>
"""
import sys
import re

def extract_pcs(infile, outfile):
    # Spike -l lines look like:
    # core   0: 0x00010000 (0x00010117) auipc   sp, 0x10
    # We want the first hex address (the PC), stripped of '0x' and lowercased.
    pattern = re.compile(r'core\s+\d+:\s+0x([0-9a-fA-F]+)\s+\(')

    count = 0
    with open(infile) as fin, open(outfile, 'w') as fout:
        for line in fin:
            match = pattern.search(line)
            if match:
                pc = match.group(1).lower()
                fout.write(pc + "\n")
                count += 1

    print(f"Extracted {count} PC values -> {outfile}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <spike_raw_log> <output_file>")
        sys.exit(1)
    extract_pcs(sys.argv[1], sys.argv[2])
