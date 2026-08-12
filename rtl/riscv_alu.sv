// riscv_alu.sv
// RISC-V ALU RV32I implementation in  System Verilog
// week10 - Towards a RISC-V processor. Implementing the ALU

module riscv_alu(
    input logic [3:0] op, // Opcode for the operation to be performed
    input logic [31:0] a, // First operand
    input logic [31:0] b, // Second operand
    output logic [31:0] result, 
    output logic zero // 1-bit flag - High when result==0 - Used by branch instr
);
    always_comb begin
        case (op)
            4'b0000 : result = a + b; // ADD
            4'b0001 : result = a - b; //SUB
            4'b0010 : result = a & b; // AND
            4'b0011 : result = a | b; // OR
            4'b0100 : result = a ^ b; // XOR
            4'b0101 : result = a << b[4:0]; // SLL
            4'b0110 : result = a >> b[4:0]; // SRL
            4'b0111 : result = $signed(a) >>> b[4:0]; // SRA
            4'b1000 : result = ($signed(a) < $signed(b)) ? 32'b1 : 32'b0;
            4'b1001 : result = (a < b) ? 32'b1 : 32'b0;
            default : result = 0;
        endcase
        zero = (result == 32'b0);

    end
endmodule