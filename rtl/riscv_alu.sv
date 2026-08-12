// riscv_alu.sv
// RISC-V ALU RV32I implementation in  System Verilog
// week10 - Towards a RISC-V processor. Implementing the ALU
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

module riscv_alu(
    input logic [4:0] op, // Opcode for the operation to be performed
    input logic [31:0] a, // First operand
    input logic [31:0] b, // Second operand
    output logic [31:0] result, 
    output logic zero // 1-bit flag - High when result==0 - Used by branch instr
);
    always_comb begin
        case (op)
            5'b00001 : result = a + b;                                      // ADD, ADDI
            5'b00010 : result = a - b;                                      // SUB
            5'b01010 : result = a & b;                                      // AND, ANDI
            5'b01001 : result = a | b;                                      // OR, ORI
            5'b00110 : result = a ^ b;                                      // XOR, XORI
            5'b00011 : result = a << b[4:0];                                // SLL, SLLI
            5'b00111 : result = a >> b[4:0];                                // SRL, SRLI
            5'b01000 : result = $signed(a) >>> b[4:0];                      // SRA, SRAI
            5'b00100 : result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;  // SLT, SLTI
            5'b00101 : result = (a < b) ? 32'b1 : 32'b0;                    // SLTU, SLTIU
            default : result = 0;
        endcase
        zero = (result == 32'b0);

    end
endmodule