#!/usr/bin/env python3
"""
diff_traces.py - compare an RTL retirement trace against a Spike PC trace,
reporting the first divergence with surrounding context.

Usage: python3 diff_traces.py <rtl_trace.log> <spike_pc_only.log>
"""
import sys

def load_pcs(filename, base_offset=0):
    pcs = []
    with open(filename) as f:
        for line in f:
            line = line.strip().lower()
            if not line:
                continue
            if line.startswith("0x"):
                line = line[2:]
            pcs.append(int(line, 16) - base_offset)
    return pcs

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <rtl_trace.log> <spike_pc_only.log> [spike_base_offset_hex]")
        print(f"  spike_base_offset_hex defaults to 0x10000 (Spike's typical ORIGIN)")
        sys.exit(1)

    spike_offset = int(sys.argv[3], 16) if len(sys.argv) > 3 else 0x10000

    rtl_pcs = load_pcs(sys.argv[1], base_offset=0)
    spike_pcs = load_pcs(sys.argv[2], base_offset=spike_offset)

    min_len = min(len(rtl_pcs), len(spike_pcs))
    for i in range(min_len):
        if rtl_pcs[i] != spike_pcs[i]:
            print(f"DIVERGENCE at retirement #{i}")
            print(f"  RTL:   0x{rtl_pcs[i]:08x}")
            print(f"  Spike: 0x{spike_pcs[i]:08x} (normalized, offset 0x{spike_offset:x} subtracted)")
            lo = max(0, i - 3)
            print(f"  Context RTL   [{lo}:{i}]: {[hex(p) for p in rtl_pcs[lo:i]]}")
            print(f"  Context Spike [{lo}:{i}]: {[hex(p) for p in spike_pcs[lo:i]]}")
            sys.exit(1)

    if len(rtl_pcs) != len(spike_pcs):
        print(f"Length mismatch: RTL={len(rtl_pcs)} Spike={len(spike_pcs)} "
              f"(all {min_len} common retirements matched)")
    else:
        print(f"MATCH: all {min_len} retirements agree")

if __name__ == "__main__":
    main()