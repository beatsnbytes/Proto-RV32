# RTL/RISC-V Tutoring — Handoff Document

This document captures everything needed to continue a long-running RTL design tutoring relationship in a new conversation. Read it fully before starting.

---

## STUDENT PROFILE

**Name:** Vatistas (Ioannis-Vatistas) Kostalabros
**Background:** PhD in digital design/computer architecture from Barcelona Supercomputing Center (BSC), cum laude 2024. Thesis: "Post-Quantum Cryptography Acceleration for Next-Generation Computers." Just returned from ~1.5-year sabbatical in Latin America.
**Prior experience:** HLS (Catapult, Vivado HLS), 2 ASIC tapeouts at GF22nm, RISC-V SoC integration, post-quantum crypto accelerators.
**Goal:** Land an RTL/RISC-V hardware design job in Barcelona.

**Hard constraints & preferences:**
- Must stay in Barcelona
- Strongly values remote flexibility (visiting family in Greece, travel) — this is a potential dealbreaker; frustrated by only 24 days/year vacation
- Can live comfortably on ~50K gross (350€/month rent)
- Prioritizes lifestyle/motivation over max salary — wants to enjoy the work
- Leans toward BSC for lifestyle despite lower pay

---

## TEACHING STYLE (STRICT — the student enforces these)

- **HINTS ONLY, never full solutions.** Student writes all code independently. Tutor reviews and gives hints. Student got upset in the past when given full code, and once demanded an apology when the tutor framed questions as "avoiding work."
- **Always explain the "why."**
- **Push complexity aggressively** — student is ahead and wants to be challenged.
- **Git discipline:** branch before work, never commit to main.
- **Don't be "mean"** — student calls this out. Be encouraging; the coding rounds are meant to make them "feel empowered."
- Keep interview blocks to 20 min so they feel substantial.
- The student is sharp, asks excellent probing questions, and often catches subtleties themselves. Treat questions as genuine understanding-building, never as avoidance.

---

## DAILY SESSION STRUCTURE (current agreed format)

1. **Coding Round 1** — write-from-scratch RTL, escalating difficulty, 20 min, no hints
2. **Coding Round 2** — second write-from-scratch, harder, 20 min, no hints
3. **Alternative problem** — rotate: debug-the-code / debug-the-waveform / complete-the-design / refactor-optimize / conceptual+code
4. **Interview block** — 20 min, concept-driven, UPDATE THE PREP DOCUMENT after each
5. **Classic RTL project work** — main build (currently the cache), time permitting

Weekly: one longer mock interview (tutor as interviewer, student codes + explains aloud, then follow-up grilling).

**NEXT SESSION FOCUS (student's explicit request):** Start with 2 (slightly harder) coding rounds + 1 alternative problem, THEN go intense on interview topics covering **timing closure and power** (student's self-identified gaps — wants them fresh, doesn't remember much from OpenROAD work). Then cache if time.

**Queued coding problem for next session (Round 1):** Synchronous FIFO with almost-full/almost-empty flags — params DEPTH, WIDTH, ALMOST_MARGIN; standard FIFO ports plus almost_full (free slots ≤ margin) and almost_empty (occupied ≤ margin); handle simultaneous read/write.

---

## ENVIRONMENT & REPO

- **OS:** Ubuntu 24.04
- **Repo:** github.com/beatsnbytes/sv-learning (local: ~/hdl_rampup/sv-learning)
- **Structure:** rtl/, tb/ (assertions/, uvm/), sim/, scripts/, synth/, docs/
- **Tools:** Verilator 5.x, GTKWave, Yosys 0.33, SymbiYosys 0.66, Z3, Boolector, riscv64-unknown-elf-gcc, OpenROAD (built via Bazel, binary at ~/hdl_rampup/install/OpenROAD/bin, on PATH)
- GTKWave has a snap conflict with VS Code integrated terminal — run sims from external terminal
- **sky130 PDK** copied into synth/sky130/ (gitignored) from an OpenROAD download: sky130_fd_sc_hs__tt_025C_1v80.lib, sky130_fd_sc_hs_merged.lef, sky130hs.tlef. Site name for floorplan is `unit`.
- program.hex must be copied into synth/cpu/ for the CPU's $readmemh at synthesis
- Verilator note: `break` inside always_comb for-loops trips multi-driver warnings; use high-to-low loop instead

---

## CURRICULUM COMPLETED (Weeks 1–21)

**Weeks 1–15 (before this transcript):** gates→counter, FSMs, param FIFO, constrained-random verif, SVA+bind, full UVM env, AXI4-Lite slave, RISC-V CPU (ALU, regfile, fetch/decode, execute, 5-stage pipeline, forwarding, branch flushing), RV32M multiplier, CSR (mtvec/mepc/mcause), formal verification suite (x0-zero, MUL busy⊕done, forwarding, CSR forwarding via k-induction/Boolector).

**Week 16 — SPI master + UART TX (DONE):** SPI Mode 0, MSB-first, sclk gated on busy. UART TX 5-state FSM, baud counter, LSB-first, defaults-before-case to avoid latches. Both verified in GTKWave.

**Week 17 — Matrix multiply accelerator (DONE):** Parameterized NxN (N=4, 32-bit), single reused MAC. Address map A:0x00-0x0F, B:0x10-0x1F, C:0x20-0x2F. Registered result+saved_i/saved_j+write_result for timing.

**Week 18 — AXI4-Lite wrapper for accelerator (DONE):** Wrapper instantiates accelerator, AXI ports face CPU. start/done memory-mapped. Byte-addressed AXI, word address = awaddr[ADDR_WIDTH+1:2]. Registered wr_addr/wr_data/wr_en aligned. start_accel single-cycle pulse. busy latch guards re-entry.

**Week 19 — OpenROAD synthesis + timing (DONE):** See detailed results below.

**Week 20 — Async FIFO / CDC (DONE, verified):** Dual-clock (clk_wr/clk_rd), Gray-coded pointers (one extra bit for full/empty), two-flop synchronizers per direction (clocked by DESTINATION clock), reset synchronizers per domain (negedge arst, assert async / deassert sync). Full = wr_ptr_gray == {~rd_ptr_gray_sync[MSB:MSB-1], rest} (Cummings formula). Empty = pointers equal. Student debugged testbench (timing: needed 1cc wait before reading registered data; used SV queue $ as reference model + fork/join for concurrent read/write). Deeply understood: 2cc sync latency is a conservative FEATURE (never overflow/underflow).

**Week 21 — Direct-mapped cache (IN PROGRESS):** See detailed status below.

---

## OPENROAD SYNTHESIS RESULTS (Week 19 — cite these in interviews)

Flow: Yosys (read_verilog → synth → dfflibmap → abc → write_verilog, mapped to sky130hs) then OpenROAD (read_lef/liberty, link_design, initialize_floorplan -site unit, report_checks).

- **ALU:** 1004 cells, all combinational (ALU has no flip-flops), 8,409 µm², critical path 4.91ns → ~200MHz. Bottleneck = ripple-carry adder (chain of maj3 cells). Fix = carry-lookahead adder.
- **Register file:** 3,449 cells, 1,024 flip-flops (32×32), 63,147 µm², critical path 3.79ns → ~264MHz. Critical path through RESET decode logic, not the read mux tree (mux4-based tree is shallow/fast). SDC input_delay matters (2ns tightens vs 0ns).
- **Full CPU:** 26,626 cells, 9,689 flip-flops, 533,438 µm² (0.53mm²). Dominant cells: 9,007 mux2 + 3,365 mux4 (forwarding + pipeline selection). Pre-placement wire delay estimate absurdly pessimistic (72ns on first FF Q output — NOT real). Real gate-level critical path ~20ns → ~50MHz unoptimized. estimate_parasitics/place_pins failed (no routing tracks in minimal LEF); used report_checks only.

Key lesson student learned: pre-placement wire delays are pessimistic estimates (can be 10-100× real); only post-route STA is accurate.

---

## WEEK 21 CACHE — DETAILED STATUS (RESUME HERE FOR PROJECT WORK)

**Branch:** week21/direct-mapped-cache
**File:** rtl/direct_mapped_cache.sv
**Spec:** Read-only direct-mapped cache. 32-bit address, 1KB cache, 16B (128-bit) lines, 64 lines, direct-mapped.
**Address breakdown:** offset=4 bits, index=6 bits, tag=22 bits (student initially miscalculated index=4, corrected to 6).

**RTL STATUS: functionally complete for reads.** Structure:
- Three separate arrays: `data_mem[64]` (128-bit), `tag_mem[64]` (22-bit), `valid_bit_mem` (64-bit vector, easy reset)
- Address extraction (built bottom-up): offset = cpu_addr[3:0], index = cpu_addr[9:4], tag = cpu_addr[31:10]
- FSM: 2 states (IDLE, MEM_REQ), typedef enum
- hit = (tag == tag_mem[index]) && valid_bit_mem[index] — deliberately NOT gated on cpu_req_ready to avoid comb loop
- Handshakes: valid/ready on all 4 channels (cpu req, cpu resp, mem req, mem resp). mem_resp_data is 128-bit (full line in one transfer).
- Output logic in always_comb with defaults-first (no latches). Hit path: word-select via offset[3:2] (`data_mem[index][offset[OFFSET_WIDTH-1:OFFSET_WIDTH-2]*32 +: 32]`). Miss path forwards mem_resp_data word, asserts cpu_resp_valid.
- Line fill in always_ff (non-blocking) on mem_resp_valid: writes data_mem/tag_mem/valid_bit_mem, sets valid.
- Student deeply understood: memories must be always_ff (state persists); outputs must be always_comb (Moore — reflect current state, don't persist).

**Known simplifications to note in interviews:**
- mem_req_valid held through MEM_REQ (a cleaner design separates send-request and wait-response into two states)
- Single-cycle 128-bit line fill (real memory returns bursts, needs a burst counter)

**PENDING Week 21:**
1. Add cleaner extra FSM states (separate send-request from wait-response)
2. Write the testbench (memory model + CPU model + scenarios: hit, miss, conflict/eviction, sequential fills)
3. Commit the branch

**Then (high-value next builds, in suggested priority order):**
1. Set-associative cache (N-way + LRU/PLRU replacement) — directly hits Semidynamics d-cache/i-cache/L2 focus
2. Accelerator-to-CPU integration (wire matrix mult accelerator into CPU memory map + RISC-V asm test program) — full SoC integration story
3. Write support for cache (write-back + dirty bits)
4. Load-use hazard stall in CPU (known gap — CPU currently lacks it)
5. Read Sargantana RTL and compare to own design (great BSC prep)

---

## INTERVIEW PREP DOCUMENT

**Files:** /mnt/user-data/outputs/interview_prep_notes.docx and .pdf
**Regeneration script:** /home/claude/interview_prep.js (run `node interview_prep.js` then soffice convert to PDF)
**NOTE:** In a new conversation the script won't exist on disk — it must be recreated, OR just append new sessions in the same docx style (Arial, blue headings #2E75B6, bullet lists via numbering config). Keep the established structure.

**Sessions completed in the document:**
1. Pipeline Hazards — RAW/WAR/WAW, control, structural; forwarding vs stalling; load-use stall (student's CPU lacks it — known gap)
2. CDC / Metastability — two-flop synchronizer, bus coherency, Gray code, async FIFO, real-world CPU-accelerator example
3. Synthesis & P&R — what each stage produces, why wire delay needs a separate later stage
4. Timing Analysis Deep Dive — slack, max freq = 1/critical-path, hold time (destination FF property), PVT corners (ss=setup-worst, ff=hold-worst), why clock can't fix hold (skew-dominated, period-independent). Student challenged and understood via skew.
5. Arbitration & Scheduling — fixed-priority starvation, round-robin (rotating priority, last_grant/mask state), weighted RR, arbiter vs scheduler, Gazzillion/memory-wall relevance
6. OpenROAD Synthesis Results — the ALU/regfile/CPU numbers above, interview story, wire-delay-vs-gate-delay lesson
7. Cache Fundamentals — tag/index/offset, hit=tag+valid, set-associative N comparators, direct-mapped vs associative thrashing, replacement policies (LRU/FIFO/PLRU/Random), security connection to student's CARRV 2020 co-authored cache-randomization paper

**PENDING interview topics (student's request — these are the GAPS to prioritize next):**
- **Timing (refresh + extend):** multicycle paths, false paths, retiming, pipelining for timing closure; refresh setup/hold/slack
- **Power (biggest gap):** dynamic vs static/leakage, P=CV²f, clock gating, power gating, operand isolation, multi-Vt cells, DVFS (student has a real hook — Trimsignal DVFS work), power domains, level shifters, isolation cells, UPF basics
- **Physical design refresh:** synthesis vs P&R, standard cells/Liberty/LEF, floorplan/placement/routing/CTS/STA flow, congestion, utilization
- **DFT basics:** scan chains (light coverage, might be asked)
- **Low-power RTL coding techniques**

---

## DAILY CODING ROUNDS — PROBLEMS DONE (all HINTS-ONLY, ~20 min each)

Student has improved from 2-3 attempts to mostly first-attempt correct. Completed:
- sync FIFO (counter-based full/empty)
- dual-port RISC-V regfile (x0-zero, latch-inference lesson: assign defaults before conditional in always_comb)
- clock divider (toggle at N/2-1 and N-1; needs $clog2(N)+1 counter width; RHS uses current values so trace carefully)
- debouncer (registered output holds last stable value; counter reset on input change)
- shift register (SISO bidirectional — first-attempt clean)
- binary↔Gray converter (bin^bin>>1; gray-to-bin cumulative XOR chain bin[i]=gray[i]^bin[i+1] or closed form ^(gray>>i); loops synthesizable if bounds fixed — unrolled)
- priority encoder (high-to-low loop beats break which trips Verilator; valid=|req not ^req)
- one-hot-to-binary encoder (counter to check exactly-one, or bit-trick one_hot&(one_hot-1)==0)
- **round-robin arbiter — ATTEMPTED, NOT FINISHED.** Student was hungover; rotation-mask concept was right but grant values miswired. DEFERRED — bring it back as a problem (not the very next session, but soon).
- **debug-the-code (broken sync FIFO)** — student found ALL bugs: count needs +1 bit, rd_data not reset, missing !full/!empty guards, simultaneous read/write breaks count (needs if/else-if: both first, then write, then read).
- **debug-the-waveform (enabled flip-flop)** — traced q capturing d at rising edges when en high, appearing one cycle later. Student correctly caught an inconsistency in the tutor's first waveform.

**Queued next (Round 1):** sync FIFO with almost-full/almost-empty flags (see Daily Structure section above).

---

## JOB SEARCH — FIVE+ ACTIVE TRACKS

**1. Semidynamics (primary):** Recruiter James Toynton (Director, IC Resources). RTL Design/Microarchitect role, seniority flexible, salary up to ~70K, office-heavy culture (1 day WFH), demanding, may involve some verification. Building AI NPU (Cervell 256 TOPS), out-of-order Atrevido cores, vector units, Gazzillion memory subsystem, SK Hynix investment, SUSE partnership. Focus areas: processor pipeline, d-cache, i-cache, L2-pipeline, custom memory controller, "vertical engineers." **CV SENT.** Strong recruiter call done (student handled name/experience/tapeout/cache questions well after practice). PENDING: technical interview scheduling. NOTE: the IC Resources "Senior FPGA Engineer" LinkedIn ad IS Semidynamics (confirmed by recruiter Carolyn Pye) — student correctly declined double-submission to avoid pipeline conflict with James.

**2. BSC (student's lifestyle first-choice):** Via former PhD supervisor Miquel Moretó. Funding CONFIRMED (internally, unofficial via Guillem — keep quiet, don't reveal when talking to Miquel). Engineering tracks (core/vector/uncore/integration) + new Nvidia 64-core AMBA-CHI + memory-controller project + a separate RE4 FPGA/Exascale role (ASIC-RTL-to-FPGA, RISC-V, HBM, PCIe — strong fit for student's tapeout+FPGA background). 3 days WFH + remote weeks (major appeal). R2 level ~50-55K. Excedencia must be formally ended before R2 hire (HR confirmed, Miquel agrees). Student messaged Miquel (excedencia ack + exploring-other-options + timing). Miquel replied "makes sense." Student to send follow-up Monday asking about September timing, mentioning other offers. Guillem shared Sargantana GitHub repos. DO NOT ask Miquel for referrals to other companies (would dilute BSC-champion relationship).

**3. OpenChip (BSC spinoff):** Via friend Victor. 100M funding for 2-3 years, ex-Apple/NVIDIA/Intel staff, SUSE partnership (sovereign RISC-V stack). 3 days WFH + remote weeks. 3 interview rounds (1 headhunt, 1+ technical, 1 HR/contract). Applied to **Emulation-Prototyping Senior Engineer** (best fit — matches PhD HLS-to-ASIC-to-FPGA work). Other roles assessed and rejected: Functional Verification (student doesn't want verification career), Junior DFT (wrong specialization), RAS Architect (too senior/specialized), Staff HW Security I/O (student's PQC is algorithm-implementation not security-architecture — poor fit). Tailored CV (FPGA/emulation emphasis) SENT, application confirmed. PENDING response.

**4. Codasip (Europe's leading RISC-V IP):** Via friend Ettore. Has a Spain design center (since 2022) — student to confirm if Barcelona/remote-compatible. FPGA engineering role. OpenChip-version CV SENT to Ettore. PENDING Ettore internal check.

**5. NVIDIA (DEFERRED by student's choice):** Friend offers referral, generally full-remote. All current hardware openings are 8+ years senior (Senior CPU Design Eng, Senior ASIC Design Eng — both relevant but too senior; the arbiter/scheduling/bus-protocol ASIC role is a great future target). Circuit Design new-grad role is analog/SPICE — wrong fit. Student wisely deferring 6-12 months to build hands-on experience, keeping referral warm. Tutor endorsed. Student to reply warmly to friend keeping door open.

**Plus:** An unnamed ASIC-design-specialist recruiter reached out — student to respond positively but ask WHICH companies before sending CV (avoid overlap with direct pipelines).

---

## CV — STATUS

**Files:** /mnt/user-data/uploads/Vatistas_Kostalabros-CV.pdf (finalized general/Semidynamics version) plus OpenChip/Codasip variant (FPGA-emphasis).
**Format:** Custom LaTeX (NOT moderncv) — \name/\work/\education/\pub macros in setup/macros.tex, overridden with \renewcommand in main.tex. Single page, 11pt, black text, light grey (#f2f2f2) name banner. Name + "Digital Design Engineer" title (title below name, \large). Middot (·) separators.

**Sections:**
- **Profile:** "PhD-qualified Digital Design Engineer with hands-on ASIC tapeout experience in RTL design and HLS. Comfortable working across the full design stack — from high-level architecture to RTL implementation. Skilled in SystemVerilog, UVM, formal verification, and RISC-V processor design." (Deliberately avoided overclaiming "advanced nodes" and "industrial-grade.")
- **Skills:** HDL&Verification (SystemVerilog·Verilog·VHDL·UVM·Formal); EDA Tools (Verilator·GTKWave·OpenROAD·Xilinx Suite·Yosys·Cadence Genus·Cadence Innovus); HLS&FPGA (Catapult HLS·Vivado HLS·Zynq UltraScale+·Alveo U280·Vitis Suite); Protocols (AXI4·SPI·UART); Programming (C·Python·RISC-V Assembly); Languages (Spanish fluent·English fluent). [Petalinux dropped for Semidynamics; keep for BSC/OpenChip FPGA versions.]
- **Work Experience (hybrid order — PhD first for impact):**
  - PhD Researcher, BSC (Sep 2018–Sep 2024): 2 ASIC tapeouts · PQC accelerator GF22nm >1GHz · UART for RISC-V SoC; HW/SW co-design of PQC accelerator up to 55.2× and 198× speedup; AXI-based integration into ARM and RISC-V platforms including Huawei research collaboration
  - RTL Engineer (Independent Research), GitHub (2025–Present): RISC-V CPU pipeline in SystemVerilog · forwarding & branch flushing · OpenROAD synth (0.53mm², ~200MHz); AXI4-Lite matrix multiply accelerator · SPI/UART peripherals · UVM & SVA verification; Async FIFO · Gray-coded pointers, CDC synchronizers
  - Research Assistant, NTUA (Nov 2015–Dec 2017): FPGA NLS Carrier Phase Recovery for 16-QAM · OFC'18 and ISCAS'18; dynamic frequency scaling accelerator · Trimsignal startup collaboration · Tcl/Python
- **Education:** PhD Computer Architecture cum laude, BSC (+ thesis line); Diploma Electrical & Computer Engineering, NTUA (+ "2 peer-reviewed publications · Independent research at NTUA Microprocessors Lab")
- **Publications (2 active, hyperlinked titles, no link icon; 3rd commented out to swap by role):**
  - ASIC-Ready Classic McEliece Accelerator in a Safety-Critical RISC-V SoC — Springer LNCS ARC 2024 — doi:10.1007/978-3-031-55673-9_20
  - Sargantana: Academic RISC-V SoC Processor in 22nm FDSOI — DCIS 2023 (co-author) — ieeexplore.ieee.org/document/10335976
  - (reserve) Leveraging HLS for a High-Performance Classic McEliece Accelerator — ACM TECS 2025 — doi:10.1145/3698395
  - (reserve, for OpenChip/Codasip FPGA versions) HLS-Based HW/SW Co-Design of Classic McEliece — IEEE FPL 2021 — doi:10.1109/FPL53798.2021.00017
  - (reserve) DVINO: RISC-V Vector Processor in 65nm — DCIS 2022 (co-author) — student designed the UART in DVINO, can defend it

**Tailoring rules:** DVINO (vector) for Semidynamics; FPL 2021 (HW/SW co-design) + FPGA-emphasis for OpenChip/Codasip; Sargantana works for BSC. Student can only defend contributions they actually made (designed UART in DVINO; for Sargantana contributed UART peripheral; primary tapeout = CM accelerator in Sargantana SoC GF22nm FDSOI Nov 2022; do NOT overclaim Sargantana specifics they don't remember).

---

## TAPEOUT FACTS (from thesis, for interview accuracy)

- **Primary tapeout:** CM (Classic McEliece) accelerator — Catapult HLS → ASIC-RTL, custom SRAMs, AXI wrapper — integrated in a RISC-V SoC, GF22nm FDSOI, Nov 2022. Student OWNS this fully (designed accelerator + custom RTL wrapper + AXI integration). Used Cadence Genus (synthesis) and Innovus (P&R). 1.13GHz, 0.59mm² for security level 1.
- **Second tapeout:** contributed UART peripheral to Sargantana SoC (BSC in-house).
- **No Huawei in thesis** but student confirms real Huawei project involvement (legitimately on CV).
- **No DVINO tapeout contribution** beyond the UART design.
- ARM/RISC-V integrations were for European projects (SELENE, NOEL-V) and BSC cores — NOT Huawei-specific.
- Platforms used: Xilinx Zynq UltraScale+ (zcu102), Alveo U280 (8GB HBM2, PCIe Gen4, Vitis), VCU118.

---

## GITHUB STATUS (cleaned up)

- Kept: sv-learning (has full portfolio README at /mnt/user-data/outputs/README.md) + 2 Classic McEliece repos (professional READMEs, left public, advised adding paper-link badges + About descriptions).
- Bio: "PhD · Digital Design Engineer · RISC-V · RTL · UVM · HLS · ASIC Tapeout | Open to opportunities in Barcelona."
- synth/sky130/ gitignored.

---

## OTHER OUTPUT FILES (in /mnt/user-data/outputs/)

- interview_prep_notes.docx / .pdf — the running interview reference (7 sessions, keep appending)
- README.md — sv-learning portfolio README
- tuesday_semidynamics_prep.docx / .pdf — earlier Semidynamics-specific prep (pitch, company info, Q&A, cache glossary, MESI)

---

## COMMUNICATION STYLE NOTES

- Student sometimes uses voice-to-text; occasional garbled transcriptions — read charitably.
- Student low-energy some days (said so when hungover) — offered lighter work (reading, videos) those days. Suggested resources: BSC EPI vector CPU talk, RISC-V 2026 updates, AI datacenter/HBM/memory-wall videos, OpenChip-SUSE news.
- Student thinking about long-term career: computer architecture vs FPGA. Concluded: open to both accelerators and microarchitecture (loved building the CPU); FPGA/accelerator roles in Barcelona are complementary not divergent; BSC FPGA/Exascale role is a strong fit. Enjoys stimulating work above all.
- Downloaded Claude Desktop — may use it for heavier file/repo editing. This handoff is because the current conversation got too long.

---

## IMMEDIATE NEXT-SESSION CHECKLIST

1. Coding Round 1: sync FIFO with almost-full/almost-empty flags (queued)
2. Coding Round 2: pick a harder write-from-scratch (escalate)
3. Alternative problem: rotate (debug/complete/refactor)
4. **Interview blocks — GO DEEP on TIMING and POWER** (student's explicit priority; power is the biggest gap; refresh OpenROAD/physical-design concepts). Update the prep document.
5. Cache work if time: cleaner FSM (split send-request/wait-response states) → testbench → commit week21/direct-mapped-cache

Pending follow-ups to remind student about: Monday message to Miquel (Sept timing + mention other offers); reply warmly to NVIDIA friend (defer, keep warm); ask the unnamed ASIC recruiter which companies before sending CV; check Codasip/Ettore location fit; revisit round-robin arbiter coding problem soon (not immediately).
