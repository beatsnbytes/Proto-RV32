// riscv_fetch_decode.sv
// Fetch and decode stage module for the RISC-V processor pipeline
// Week10 - Fetch and Decode stages


module riscv_fetch_decode (
    input logic clk,
    input logic rst,
    input logic [31:0] pc,
    output logic [4:0] rs1_addr,
    output logic [4:0] rs2_addr,
    output logic [4:0] rd_addr,
    output logic [31:0] imm,
    output logic [3:0] exec_op,
    output logic reg_wr_en,
    output logic [31:0] instr,
    output logic use_imm, // 0 = use rs2, 1 use imm
    output logic branch,
    output logic [2:0] func3,
    // Output signals from LW/SW instr
    output logic memory_read, 
    output logic memory_write,
    output logic memory_to_reg, // 0 = ALU_RESULT, 1 = memory data
    output logic mul_start,
    // Output signals for the CSR file
    output logic csr_wr_en, 
    output logic csr_rd_en, 
    output logic [11:0] csr_addr, 
    output logic csr_rw
);

    logic [31:0] imem [255:0]; // The 1KB instruction memory

    `ifdef FORMAL
        // imem left unconstrained for formal verification
    `else
        initial $readmemh("program.hex", imem); // Reading the instructions from a hex file
    `endif

    logic [6:0] opcode;
    logic [6:0] func7;

    logic mult_start;

    assign instr = imem[pc[9:2]];
    assign opcode = instr[6:0];
    assign func3 = instr[14:12];
    assign func7 = instr[31:25];
    assign rs1_addr = instr[19:15];
    assign rs2_addr = instr[24:20];
    assign rd_addr = instr[11:7];

    always_comb begin

        exec_op = 4'b0000; // Default ADD
        reg_wr_en = 1'b0;
        imm = 32'b0;
        use_imm = 1'b0; // Get value from rs2
        branch = 1'b0;
        // Default signals for data memory
        memory_read = 1'b0;
        memory_write = 1'b0;
        memory_to_reg = 1'b0;
        // Default signals for multiplier
        mul_start = 1'b0;
        // Default signals for CSR
        csr_rd_en  = 1'b0;
        csr_wr_en = 1'b0;
        csr_addr = 12'b0;
        csr_rw = 1'b0;
        

        case (opcode) 
            // 7'b0110011 — R-type  (ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU)
            7'b0110011 : begin
                use_imm = 1'b0;
                reg_wr_en = 1'b1;
                case (func3)
                    // ADD/SUB and MUL
                    // 3'b000 : exec_op = (func7 == 7'b0000000) ? 4'b0000 : 4'b0001;
                    3'b000 : begin
                        case (func7)
                            7'b0000000 : exec_op = 4'b0000;
                            7'b0100000 : exec_op = 4'b0001;
                            7'b0000001 : begin
                                exec_op = 4'b1010;
                                mul_start = 1'b1;
                                reg_wr_en = 1'b1;
                            end 
                            default : exec_op = 4'b0000;
                        endcase
                    end
                    // AND
                    3'b111  : exec_op = 4'b0010;
                    // OR
                    3'b110 : exec_op = 4'b0011;
                    // XOR
                    3'b100 : exec_op = 4'b0100;
                    // MULH SLL
                    3'b001 : begin
                        case (func7)
                            7'b0000001 : begin
                                exec_op = 4'b1011;
                                mul_start = 1'b1;
                                reg_wr_en = 1'b1;
                            end
                            default: exec_op = 4'b0101;
                        endcase
                    end 
                    // SRL/SRA
                    3'b101 : exec_op = func7[5] ? 4'b0111 : 4'b0110;
                    // SLT
                    3'b010 : exec_op = 4'b1000;
                    // SLTU
                    3'b011 : exec_op = 4'b1001;  
                endcase
            end
            // 7'b0010011 — I-type  (ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU)
            7'b0010011: begin
                use_imm = 1'b1;
                reg_wr_en = 1'b1;
                imm = {{20{instr[31]}}, instr[31:20]};
                case(func3)
                    // ADDI
                    3'b000 : exec_op = 4'b0000;
                    // SLLI
                    3'b001 : exec_op = 4'b0101;
                    // SLTI
                    3'b010 : exec_op = 4'b1000;
                    // SLTIU
                    3'b011 : exec_op = 4'b1001;
                    // XORI
                    3'b100 : exec_op = 4'b0100;
                    // SRLI/SRAI
                    3'b101 : exec_op = func7[5] ? 4'b0111 : 4'b0110;
                    // ORI
                    3'b110 : exec_op = 4'b0011; 
                    // ANDI
                    3'b111 : exec_op = 4'b0010;    
                endcase
            end
            // 7'b1100011 B-Type instructions BEQ, BNE
            7'b1100011 : begin
                // use_imm = 1'b0;
                imm = { {20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
                branch = 1'b1;
                exec_op = 4'b0001; // SUB  rs1 - rs2, check zero flag
            end
            // 7'b0000011 LW
            7'b0000011 : begin
                memory_read = 1'b1;
                reg_wr_en = 1'b1;
                memory_to_reg = memory_read && reg_wr_en;
                imm = {{20{instr[31]}}, instr[31:20]}; 
                use_imm = 1'b1;
                // exec_op is 4'b0000 ADD as the default case
            end
            // 7'b0100011 SW
            7'b0100011 : begin
                memory_write = 1'b1;
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
                use_imm = 1'b1;
                // exec_op is 4'b0000 ADD as the default case
            end
            // CSRRW, CSRRS 
            7'b1110011: begin
                csr_rw = (func3 == 3'b001) ? 1'b1 : 1'b0; // Signal that is set when csrrw and unset otherwise
                csr_wr_en = 1'b1;
                csr_rd_en = 1'b1;
                csr_addr = instr[31:20];
                reg_wr_en = 1'b1;
            end
            default : ; // All signals already set by the top level default
        endcase
    end

endmodule
    