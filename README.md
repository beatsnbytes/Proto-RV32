# ProtoCore — RISC-V 32IM Core Portfolio

*From the Greek "πρώτο" (próto) — first.*

A free-time side project exploring digital design and verification in SystemVerilog — going wherever it leads, down whatever challenging paths turn up along the way. Centered on ProtoCore, a pipelined RISC-V CPU now running real compiled software, verified against a golden reference model, and synthesized on real FPGA fabric.

**Author:** Vatistas Kostalabros
**Goal:** No fixed goal, really — just going deeper into digital design and verification, RISC-V and beyond, wherever the interesting problems are.

---

## What's Inside

### RISC-V CPU Pipeline — ProtoCore
A fully functional 5-stage pipelined RISC-V CPU implementing the RV32IM ISA, with the Zicsr extension:
- **IF/ID → EX → MEM → WB** pipeline with pipeline registers
- **Forwarding unit** — resolves RAW hazards without stalling
- **Hazard detection** — load-use stall insertion, cache-miss stall handling (`mem_stall`), correctly prioritized against branch redirects
- **Branch flushing** — taken-branch redirect with correct freeze/bubble discipline across pipeline stages
- **Sub-word loads/stores** — LB/LH/LBU/LHU and SB/SH, byte-enable masking, verified through a write-back cache's full dirty-eviction path
- **RV32M Multiplier & Divider** — full-width multiplier (MUL/MULH/MULHSU/MULHU) and restoring-division-based divider (DIV/DIVU/REM/REMU), both multi-cycle with correct stall integration
- **CSR registers (Zicsr)** — `mcycle`/`minstret` performance counters, verified accurate (mcycle counts every clock cycle including stalls; minstret counts genuine retirements only)
- **Write-back cache** — direct-mapped, dirty-bit tracked, verified through forced eviction and write-back to a golden-model main memory

### Software Toolchain & Verification Infrastructure
- **Full bare-metal RISC-V GNU toolchain** (`riscv32-unknown-elf-gcc`, RV32IM_Zicsr/ilp32) built from source, plus Spike (the reference ISA simulator)
- **Custom linker scripts and startup code** (`start.s`) — safe, linker-computed memory regions (`_telemetry_start`, cache-line-aligned) instead of hardcoded addresses
- **CoreMark ported and running end-to-end** — full standard configuration (`TOTAL_DATA_SIZE=2000`, all three sub-benchmarks: list, matrix, state), producing a real, verified CoreMark/MHz figure
- **Spike lockstep co-simulation** — per-retirement PC trace comparison between RTL and a golden Spike reference, on the exact same compiled binary (built with `-mno-relax` to guarantee byte-identical instruction sequences regardless of link address)
- **`build.sh`** — a single script driving every target: Spike interactive debug, RTL hex generation, Spike/RTL lockstep trace generation, and CoreMark builds for both targets

### Hardware Accelerators
- **Matrix Multiply Accelerator** — parameterized NxN systolic-style MAC unit
- **AXI4-Lite Wrapper** — memory-mapped register interface for CPU-accelerator integration
- **SPI Master** — Mode 0, MSB-first, parameterized CLKDIV and DATA_WIDTH
- **UART TX** — configurable baud rate, 8N1 framing, send_bit exposed for verification

### Verification
- **Spike lockstep co-simulation** — real reference-model verification against a golden ISA simulator, run against the full CoreMark benchmark
- **UVM Environment** — full FIFO UVM testbench (agent, driver, monitor, scoreboard)
- **SVA Assertions** — bind-based assertion modules for FIFO, register file, multiplier, CPU forwarding
- **Formal Verification** — SymbiYosys k-induction proofs:
  - x0 register always zero
  - MUL busy ⊕ done (never simultaneously asserted)
  - Forwarding unit correctness (fwd_a, fwd_b)
  - CSR forwarding correctness
- **Constrained Random Verification** — FIFO coverage-driven testbench

### Physical Implementation
- **Vivado synthesis + implementation** — full CPU pipeline synthesized and placed-and-routed on real FPGA fabric (Artix-7/Zynq-7000 class device). First attempt at 100MHz failed timing (-3.5ns slack); root-caused via schematic cross-referencing to a 13-level EX-stage forwarding/mux/register-file-address chain. Clean, passing timing closure achieved at 15ns period (~67MHz, +1.38ns slack).
- **OpenROAD synthesis** — ALU synthesized to sky130hs standard cells
- **Timing analysis** — critical path identified at ~200MHz on sky130 (ALU, combinational)
- **Yosys synthesis** — gate-level netlists with Liberty file mapping

---

## CoreMark Result

```
iterations=300, TOTAL_DATA_SIZE=2000 (standard config, all algorithms)
total_cycles=1,654,716,380
instructions=354,535,687
crc=0x988c
total_errors=0
```

At an assumed 100MHz target clock: **~0.181 CoreMark/MHz**. Modest relative to typical published RV32IM cores (2–3+ CoreMark/MHz) — expected for a straightforward single-issue in-order pipeline with a correctness-first multiplier/divider, not yet tuned for throughput. The value of this number is that it is real, lockstep-verified, and trustworthy.

Measured IPC on this workload: **0.2143**. Confirmed stable across three independent runs spanning a 30x range in scale — 10, 100, and 300 iterations gave 5,515,706, 5,515,762, and 5,515,721 cycles/iteration respectively (all within ~0.001% of each other) and identical 0.2143 IPC every time, ruling out per-iteration drift or accumulating measurement error. Also cross-checked against CoreMark's own internally-reported cycle count, which matches within a few hundred cycles (the small window difference between CoreMark's own timing calls and the wrapping telemetry measurement).

---

## Project Structure

```
sv-learning/
├── rtl/                    # RTL source files
│   ├── cpu/                # RISC-V CPU pipeline modules
│   │   ├── riscv_cpu.sv
│   │   ├── riscv_alu.sv
│   │   ├── riscv_regfile.sv
│   │   ├── riscv_fetch_decode.sv
│   │   ├── riscv_execute.sv
│   │   ├── riscv_mul.sv
│   │   ├── riscv_div.sv
│   │   └── riscv_csr.sv
│   ├── riscv_alu.sv
│   ├── main_memory.sv      # golden-model behavioral memory
│   ├── fifo.sv
│   ├── axi4_lite_slave.sv
│   ├── matrix_multiplication.sv
│   ├── matrix_multiplication_axi_wrapper.sv
│   ├── spi_master.sv
│   └── uart_tx.sv
├── sw/
│   └── bringup/
│       ├── src/             # start.s, linker scripts, test C programs
│       └── build/           # generated ELF/hex/disassembly (gitignored)
├── tb/                     # Testbenches
│   ├── assertions/         # SVA bind modules
│   │   ├── fifo_assertions.sv
│   │   ├── regfile_formal.sv
│   │   ├── mul_formal.sv
│   │   └── cpu_fwd_formal.sv
│   └── uvm/                # UVM FIFO environment
├── scripts/                # build.sh, bin2hex.py, spike_format.py, diff_traces.py, Makefile, formal scripts
│   ├── build.sh
│   ├── bin2hex.py
│   ├── spike_format.py
│   ├── diff_traces.py
│   ├── Makefile
│   ├── regfile_formal.sby
│   ├── mul_formal.sby
│   └── cpu_fwd_formal.sby
├── synth/                  # OpenROAD synthesis scripts and results
│   ├── synth_alu.ys
│   └── sky130/             # sky130hs PDK files
├── vivado/                 # Vivado project (CPU synthesis/implementation)
└── sim/                    # Simulation outputs (VCD waveforms)
```

---

## Tools & Environment

| Tool | Version | Purpose |
|------|---------|---------|
| Verilator | 5.x | RTL simulation |
| GTKWave | apt | Waveform viewing |
| Yosys | 0.33 | Synthesis |
| SymbiYosys | 0.66 | Formal verification |
| Z3 / Boolector | — | SMT solvers for formal |
| OpenROAD | 26Q1 | Place, route, STA |
| Vivado | 2026.1 | FPGA synthesis, implementation, timing closure |
| riscv32-unknown-elf-gcc | built from source (RV32IM_Zicsr/ilp32) | Full bare-metal C/assembly toolchain |
| Spike | riscv-isa-sim | Golden-model ISA simulator, lockstep reference |
| CoreMark | EEMBC | Industry-standard embedded benchmark |

**OS:** Ubuntu 24.04

---

## Running Simulations

All simulations are run from the `scripts/` directory:

```bash
cd scripts/

# Run a specific testbench
make TOP=riscv_cpu_tb sim

# Run SPI master testbench
make TOP=spi_master_tb sim

# Run UART testbench
make TOP=uart_tb sim

# Run matrix multiplier AXI wrapper testbench
make TOP=matrix_multiplication_axi_wrapper_tb sim
```

> **Note:** Run simulations from an external terminal — GTKWave has a snap conflict with VS Code integrated terminal.

---

## Running the Software Toolchain

```bash
cd scripts/

# Build + run a custom C test program on Spike (interactive debug)
./build.sh spike

# Build a custom C test program for RTL simulation (produces hex files)
./build.sh rtl

# Build the same program for Spike + generate a lockstep reference trace
./build.sh rtl-trace

# Build and run CoreMark for RTL simulation
COREMARK_ITERATIONS=100 ./build.sh coremark-rtl

# Build and run CoreMark on Spike directly
COREMARK_ITERATIONS=100 ./build.sh coremark-spike

# Diff an RTL retirement trace against a Spike reference trace
python3 diff_traces.py <rtl_trace.log> <spike_pc_only.log>
```

---

## Running Formal Verification

```bash
cd scripts/

# Prove x0 always zero (k-induction)
sby -f regfile_formal.sby

# Prove MUL busy XOR done
sby -f mul_formal.sby

# Prove forwarding unit correctness
sby -f cpu_fwd_formal.sby
```

All proofs pass by k-induction using Boolector as the SMT backend.

---

## Running Synthesis

### Vivado (CPU pipeline, FPGA target)
Open the project in `vivado/`, run Synthesis then Implementation. Current known-good timing constraint: 15ns clock period (~67MHz). Note: synthesizing the bare CPU (without the SoC's memory/cache wrapping it) requires either a `dont_touch` constraint or a minimal synthesizable memory-interface stub, since the CPU's memory-interface signals otherwise appear as unconnected top-level I/O and get optimized away or exceed available device pins.

### OpenROAD (ALU, ASIC-style flow)
```bash
cd synth/

# Synthesize ALU with sky130hs standard cell library
yosys synth_alu.ys

# Run OpenROAD floorplan and timing analysis
openroad alu_floorplan.tcl
```

**Result:** ALU critical path 4.91ns → ~200MHz achievable frequency on sky130hs. Critical path identified through ripple-carry adder chain — architectural fix: carry-lookahead adder.

---

## Known Limitations

- Exception handling incomplete — mepc/mcause written by hardware not yet implemented
- Misaligned PC and illegal instruction exceptions not implemented
- Cache is single-outstanding/blocking — no MSHRs, one miss serviced at a time
- Cache line write-back currently requires a manual same-index/different-tag aliasing trick to force eviction; no dedicated flush instruction yet
- SPI slave not yet started
- UART RX not yet started
- Matrix multiplier: fixed-width accumulator (potential overflow at high data sizes)
- OpenROAD flow: combinational ALU only — sequential module timing pending
- CoreMark/MHz figure (0.181) reflects a correctness-first, not yet performance-tuned design; EX-stage forwarding/mux/regfile-address path identified as the current timing-critical bottleneck via Vivado analysis

---

## License

See [LICENSE](LICENSE) for details.
