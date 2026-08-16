// riscv_fetch_decode.sv
// Fetch and decode stage module for the RISC-V processor pipeline
// Week10 - Fetch and Decode stages

// =====================================================================
// RV32IM (+ CSR) instruction reference — assign your own exec_op codes
// opcode / funct3 / funct7 are SPEC-FIXED. exec_op is YOURS to define.
// '-' = field not used for that instruction's decode.
// =====================================================================
//
// ---- R-type ALU (opcode 0110011, funct7 distinguishes ADD/SUB, SRL/SRA) ----
//  ADD     R  op=0110011  f3=000  f7=0000000  // exec_op: ALU add
//  SUB     R  op=0110011  f3=000  f7=0100000  // exec_op: ALU sub
//  SLL     R  op=0110011  f3=001  f7=0000000  // exec_op: ALU shift-left-logical
//  SLT     R  op=0110011  f3=010  f7=0000000  // exec_op: ALU set-less-than signed
//  SLTU    R  op=0110011  f3=011  f7=0000000  // exec_op: ALU set-less-than unsigned
//  XOR     R  op=0110011  f3=100  f7=0000000  // exec_op: ALU xor
//  SRL     R  op=0110011  f3=101  f7=0000000  // exec_op: ALU shift-right-logical
//  SRA     R  op=0110011  f3=101  f7=0100000  // exec_op: ALU shift-right-arith
//  OR      R  op=0110011  f3=110  f7=0000000  // exec_op: ALU or
//  AND     R  op=0110011  f3=111  f7=0000000  // exec_op: ALU and
//
// ---- M-extension MUL family (opcode 0110011, funct7=0000001) ----
//  MUL     R  op=0110011  f3=000  f7=0000001  // mul: low32, sign irrelevant
//  MULH    R  op=0110011  f3=001  f7=0000001  // mul: high32, rs1 signed  / rs2 signed
//  MULHSU  R  op=0110011  f3=010  f7=0000001  // mul: high32, rs1 signed  / rs2 unsigned
//  MULHU   R  op=0110011  f3=011  f7=0000001  // mul: high32, rs1 unsigned/ rs2 unsigned
//
// ---- M-extension DIV family (opcode 0110011, funct7=0000001) ----
//  DIV     R  op=0110011  f3=100  f7=0000001  // div: signed quotient
//  DIVU    R  op=0110011  f3=101  f7=0000001  // div: unsigned quotient
//  REM     R  op=0110011  f3=110  f7=0000001  // div: signed remainder
//  REMU    R  op=0110011  f3=111  f7=0000001  // div: unsigned remainder
//
// ---- I-type ALU (opcode 0010011; SLLI/SRLI/SRAI use funct7 on shamt) ----
//  ADDI    I  op=0010011  f3=000  f7=-        // ALU add, use_imm
//  SLLI    I  op=0010011  f3=001  f7=0000000  // ALU sll, shamt=imm[4:0]
//  SLTI    I  op=0010011  f3=010  f7=-        // ALU slt, use_imm
//  SLTIU   I  op=0010011  f3=011  f7=-        // ALU sltu, use_imm
//  XORI    I  op=0010011  f3=100  f7=-        // ALU xor, use_imm
//  SRLI    I  op=0010011  f3=101  f7=0000000  // ALU srl, shamt=imm[4:0]
//  SRAI    I  op=0010011  f3=101  f7=0100000  // ALU sra, shamt=imm[4:0]
//  ORI     I  op=0010011  f3=110  f7=-        // ALU or, use_imm
//  ANDI    I  op=0010011  f3=111  f7=-        // ALU and, use_imm
//
// ---- Loads (opcode 0000011) ----
//  LB      I  op=0000011  f3=000  f7=-        // load byte (sign-ext)
//  LH      I  op=0000011  f3=001  f7=-        // load half (sign-ext)
//  LW      I  op=0000011  f3=010  f7=-        // load word
//  LBU     I  op=0000011  f3=100  f7=-        // load byte (zero-ext)
//  LHU     I  op=0000011  f3=101  f7=-        // load half (zero-ext)
//
// ---- Stores (opcode 0100011) ----
//  SB      S  op=0100011  f3=000  f7=-        // store byte
//  SH      S  op=0100011  f3=001  f7=-        // store half
//  SW      S  op=0100011  f3=010  f7=-        // store word
//
// ---- Branches (opcode 1100011) ----
//  BEQ     B  op=1100011  f3=000  f7=-        // branch if equal
//  BNE     B  op=1100011  f3=001  f7=-        // branch if not equal
//  BLT     B  op=1100011  f3=100  f7=-        // branch if less-than signed
//  BGE     B  op=1100011  f3=101  f7=-        // branch if >= signed
//  BLTU    B  op=1100011  f3=110  f7=-        // branch if less-than unsigned
//  BGEU    B  op=1100011  f3=111  f7=-        // branch if >= unsigned
//
// ---- Jumps ----
//  JAL     J  op=1101111  f3=-    f7=-        // jump and link
//  JALR    I  op=1100111  f3=000  f7=-        // jump and link register
//
// ---- Upper immediate ----
//  LUI     U  op=0110111  f3=-    f7=-        // load upper immediate
//  AUIPC   U  op=0010111  f3=-    f7=-        // add upper imm to pc
//
// ---- CSR / SYSTEM (opcode 1110011) ----
//  CSRRW   I  op=1110011  f3=001  f7=-        // csr read/write
//  CSRRS   I  op=1110011  f3=010  f7=-        // csr read/set (OR)
//  CSRRC   I  op=1110011  f3=011  f7=-        // csr read/clear (AND ~)
//  CSRRWI  I  op=1110011  f3=101  f7=-        // csr read/write imm
//  CSRRSI  I  op=1110011  f3=110  f7=-        // csr read/set imm
//  CSRRCI  I  op=1110011  f3=111  f7=-        // csr read/clear imm
//

// =====================================================================
// exec_op ASSIGNMENT WORKSHEET  (5-bit exec_op = 5'bxxxxx)
// Fill the EXEC_OP column. Same operation shared by R and I forms.
// Suggested structure (Scheme B):
//   bit[4] = is-multicycle (mul/div) : 0=ALU/other, 1=MUL/DIV unit
//   within muldiv: bit[3]=div(1)/mul(0); low bits = variant/props
//   reserve 5'b00000 = NOP/bubble (inert). Move ADD off 0.
// =====================================================================
//
// OPERATION          INSTRS THAT USE IT                 EXEC_OP     NOTES
// -----------------  --------------------------------  ---------   -----------------------------
// -- ALU / single-cycle (bit[4]=0) --
//  ALU_ADD           ADD, ADDI, (LW/SW/JALR addr calc) 5'b00001   base add; addr gen too
//  ALU_SUB           SUB                               5'b00010
//  ALU_SLL           SLL, SLLI                         5'b00011
//  ALU_SLT           SLT, SLTI                         5'b00100   signed set-less-than
//  ALU_SLTU          SLTU, SLTIU                       5'b00101   unsigned
//  ALU_XOR           XOR, XORI                         5'b00110
//  ALU_SRL           SRL, SRLI                         5'b00111
//  ALU_SRA           SRA, SRAI                         5'b01000   arith shift
//  ALU_OR            OR, ORI, (CSRRS set)              5'b01001   reused for CSR set
//  ALU_AND           AND, ANDI, (CSRRC clear via AND~) 5'b01010   reused for CSR clear
//  ALU_LUI           LUI                               5'b01011   pass imm (or add x0)
//  ALU_AUIPC         AUIPC                             5'b01100   pc + imm
//
// -- MUL family (bit[4]=1, bit[3]=0) --
//  MUL_LO            MUL                               5'b10000   low32  bit[2]=0; sign irrelevant
//  MUL_H_SS          MULH                              5'b10111   high32 bit[2]=1; rs1 s bit[1]=1 / rs2 s bit[0]=1
//  MUL_H_SU          MULHSU                            5'b10110   high32; rs1 s / rs2 u
//  MUL_H_UU          MULHU                             5'b10100   high32; rs1 u / rs2 u
//
// -- DIV family (bit[4]=1, bit[3]=1) --
//  DIV_S             DIV                               5'b11001   signed bit[0]=1 quotient bit[1]=0
//  DIV_U             DIVU                              5'b11000   unsigned bit[0]=0 quotient
//  REM_S             REM                               5'b11011   signed remainder bit[1] = 1
//  REM_U             REMU                              5'b11010   unsigned remainder
//
// -- special --
//  NOP/BUBBLE        (flush/stall inserts this)        5'b00000   inert: no wr, no stall, no unit
//
// NOTE: branches, loads/stores, jumps, CSR plumbing are routed by
//       OPCODE + dedicated control signals — NOT by exec_op.
//       exec_op only names the FUNCTIONAL-UNIT OPERATION.


module riscv_fetch_decode (
    input logic clk,
    input logic rst,
    input logic [31:0] pc,
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    output logic [4:0] rd_addr,
    output logic [31:0] imm,
    output logic [4:0] exec_op, // 32 instructions are enough for the whole rv32im extension
    output logic reg_wr_en,
    output logic [31:0] instr,
    output logic use_imm, // 0 = use rs2, 1 use imm
    output logic branch_instr,
    output logic [2:0] func3,
    // Output signals from LW/SW instr
    output logic memory_read, 
    output logic memory_write,
    output logic memory_to_reg, // Writeback mux 0 = ALU_RESULT, 1 = memory data
    // Output signals for the CSR file
    output logic csr_wr_en, 
    output logic csr_rd_en, 
    output logic [11:0] csr_addr, 
    output logic csr_rw
);

//TODO Are any signals now irrelevant to be created here and we could derive them from the ex_op bits?

    `ifdef FORMAL
        // imem left unconstrained for formal verification
    `else
        initial $readmemh("program.hex", imem); // Reading the instructions from a hex file
    `endif

    logic [31:0] imem [255:0]; // The 1KB instruction memory
    logic [6:0] opcode;
    logic [6:0] func7;


    assign instr = imem[pc[9:2]];
    assign opcode = instr[6:0];
    assign func3 = instr[14:12];
    assign func7 = instr[31:25];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr = instr[11:7];

    always_comb begin

        exec_op = 5'b00000; // Default NOP
        reg_wr_en = 1'b0;
        imm = 32'b0;
        use_imm = 1'b0; // Get value from rs2
        branch_instr = 1'b0;
        // Default signals for data memory
        memory_read = 1'b0;
        memory_write = 1'b0;
        memory_to_reg = 1'b0;
        // Default signals for CSR
        csr_rd_en  = 1'b0;
        csr_wr_en = 1'b0;
        csr_addr = 12'b0;
        csr_rw = 1'b0;
        case (opcode) 
            7'b0110011 : begin
                // R-type ALU, M-extension
                reg_wr_en = 1'b1;
                case(func7)
                    7'b0000000: begin
                        // ---- R-type ALU (opcode 0110011, funct7 distinguishes ADD/SUB, SRL/SRA) ----
                        case(func3)
                            3'b000: exec_op = 5'b00001; // ADD
                            3'b001: exec_op = 5'b00011; // SLL
                            3'b010: exec_op = 5'b00100; // SLT
                            3'b011: exec_op = 5'b00101; // SLTU
                            3'b100: exec_op = 5'b00110; // XOR
                            3'b101: exec_op = 5'b00111; // SRL
                            3'b110: exec_op = 5'b01001; // OR
                            3'b111: exec_op = 5'b01010; // AND 
                        endcase
                    end
                    7'b0000001: begin 
                        // ---- M-extension MUL & DIV family (opcode 0110011, funct7=0000001) ----
                        reg_wr_en = 1'b1;
                        case(func3)
                            3'b000: exec_op = 5'b10000; // MUL
                            3'b001: exec_op = 5'b10111; // MULH
                            3'b010: exec_op = 5'b10110; // MULHSU
                            3'b011: exec_op = 5'b10100; // MULHU
                            3'b100: exec_op = 5'b11001; // DIV
                            3'b101: exec_op = 5'b11000; // DIVU
                            3'b110: exec_op = 5'b11011; // REM
                            3'b111: exec_op = 5'b11010; // REMU
                        endcase
                    end
                    7'b0100000: begin
                        // SUB & SRA
                        case(func3)
                            3'b000: exec_op = 5'b00010; // SUB
                            3'b101: exec_op = 5'b01000; // SRA
                            default: exec_op = 5'b00000; // NOP
                        endcase
                    end
                    default:;
                endcase
            end
            7'b0010011 : begin
            // I-type ALU
                use_imm = 1'b1;
                reg_wr_en = 1'b1;  
                imm = {{20{instr[31]}}, instr[31:20]};
                // ---- I-type ALU (opcode 0010011; SLLI/SRLI/SRAI use funct7 on shamt) ----
                case(func3)
                    3'b000: exec_op = 5'b00001; // ADDI
                    3'b001: exec_op = 5'b00011; // SLLI
                    3'b010: exec_op = 5'b00100; // SLTI
                    3'b011: exec_op = 5'b00101; // SLTIU
                    3'b100: exec_op = 5'b00110; // XORI
                    3'b101: begin
                        case(func7)
                            7'b0000000: exec_op = 5'b00111; // SRLI
                            7'b0100000: exec_op = 5'b01000; // SRAI
                            default: exec_op = 5'b00000; // NOP
                        endcase
                    end
                    3'b110: exec_op = 5'b01001; // ORI
                    3'b111: exec_op = 5'b01010; // ANDI 
                endcase
            end
            // -- B-Type instructions BEQ, BNE
            // func3 = 3'b000 is BEQ and func3 = 3'b001 is BNE
            7'b1100011 : begin
                imm = { {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
                branch_instr = 1'b1;
                case(func3)
                    3'b000: exec_op = 5'b00010; // BEQ (SUB)
                    3'b001: exec_op = 5'b00010; // BNE (SUB)
                    3'b100: exec_op = 5'b00100; // BLT (SLT)
                    3'b101: exec_op = 5'b00100; // BGE (SLT)
                    3'b110: exec_op = 5'b00101; // BLTU (SLTU)
                    3'b111: exec_op = 5'b00101; // BGEU (SLTU)
                    default: exec_op = 5'b00000; // NOP
                endcase
            end
            // -- LW
            7'b0000011 : begin
                memory_read = 1'b1;
                reg_wr_en = 1'b1;
                memory_to_reg = 1'b1; // memory_read && reg_wr_en
                imm = {{20{instr[31]}}, instr[31:20]}; 
                use_imm = 1'b1;
                exec_op = 5'b00001; // Use the ADD to compute the address
            end
            // -- SW
            7'b0100011 : begin
                memory_write = 1'b1;
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                use_imm = 1'b1;
                exec_op = 5'b00001; // Use the ADD to compute the address
            end
            //TODO need fixing. I now only cater for a small part of this. Implement from start and verify they are ok!
            // -- CSRRW, CSRRS 
            7'b1110011: begin
                csr_rw = (func3 == 3'b001) ? 1'b1 : 1'b0; // Signal that is set when csrrw and unset otherwise
                csr_wr_en = 1'b1;
                csr_rd_en = 1'b1;
                csr_addr = instr[31:20];
                reg_wr_en = 1'b1;
            end
            7'b0110111: begin // LUI
                imm = {{12{instr[31]}}, instr[31:12]};
                use_imm = 1'b1;
                reg_wr_en = 1'b1;
                exec_op = 5'b01011;
            end
            7'b0010111 : begin // AUIPC
                imm = {{12{instr[31]}}, instr[31:12]};
                use_imm = 1'b1;
                reg_wr_en = 1'b1;
                exec_op = 5'b01100;
            end
            default : ; // All signals already set by the top level default
        endcase
    end

    // always_comb begin : control_signals_from_exec_op
    // //TODO add more signals here that are derived from exec_op
    //     is_muldiv_instr = exec_op[4];
    // end

endmodule
    