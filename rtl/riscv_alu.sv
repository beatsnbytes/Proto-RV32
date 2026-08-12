// riscv_alu.sv
// RISC-V ALU RV32I implementation in  System Verilog
// week10 - Towards a RISC-V processor. Implementing the ALU

module riscv_alu(
    input logic [4:0] op, // Opcode for the operation to be performed
    input logic [31:0] a, // First operand
    input logic [31:0] b, // Second operand
    output logic [31:0] result, 
    output logic zero // 1-bit flag - High when result==0 - Used by branch instr
);
    always_comb begin
        case (op)
            5'b00000 : result = a + b; // ADD
            5'b00001 : result = a - b; //SUB
            5'b00010 : result = a & b; // AND
            5'b00011 : result = a | b; // OR
            5'b00100 : result = a ^ b; // XOR
            5'b00101 : result = a << b[4:0]; // SLL
            5'b00110 : result = a >> b[4:0]; // SRL
            5'b00111 : result = $signed(a) >>> b[4:0]; // SRA
            5'b01000 : result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
            5'b01001 : result = (a < b) ? 32'b1 : 32'b0;
            default : result = 0;
        endcase
        zero = (result == 32'b0);

    end
endmodule