// riscv_execute.sv
// The execute stage of the RISC-V processor
// Week10 - Bringing it all together with the execute stage

module riscv_execute (
    input logic clk,
    input logic rst,
    // From the fetch & decode
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [4:0] rd_addr,
    input logic reg_wr_en,
    input logic use_imm,
    input logic [3:0] exec_op,
    input logic [31:0] imm,
    input logic [31:0] mem_fwd_data,
    input logic [31:0] wb_fwd_data,
    input logic [31:0] wb_data,
    input logic [1:0] fwd_to_rs1, 
    input logic [1:0] fwd_to_rs2,
    input logic [4:0] wb_rd_addr,
    input logic wb_reg_wr_en, 
    input logic mul_start,
    // CSR-related
    input logic [31:0] csr_rd_data,
    input logic csr_rd_en, 
    input logic csr_rw, 
    // ALU-related
    output logic [31:0] exec_result,
    output logic zero,
    output logic [31:0] memory_wr_data,
    output logic mul_busy,
    input logic mul_to_reg,
    output logic [31:0] csr_wr_data
);

    // From the regfile
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] op_a;
    logic [31:0] op_b;
    logic [31:0] rs2_fwd_data;
    logic [31:0] mul_result;
    logic [31:0] alu_result;
    logic [31:0] mul_result_latched;
    logic result_src; // Mux signal for selecting mul or alu result

    // MUX logic forwarding the correct value to the ALU
    always_comb begin
        case(fwd_to_rs1)
            2'b00: op_a = rs1_data;
            2'b10: op_a = mem_fwd_data;
            2'b11: op_a = wb_fwd_data;
            default: op_a = rs1_data; // Defaulting to rs1 data for the invalid value of 10
        endcase

        case(fwd_to_rs2)
            2'b00: rs2_fwd_data = rs2_data;
            2'b10: rs2_fwd_data = mem_fwd_data;
            2'b11: rs2_fwd_data = wb_fwd_data;
            default: rs2_fwd_data = rs2_data; // Defaulting to rs2 data for the invalid value of 10
        endcase

        // MUX selecting between the immediate and the rs2_fwd_data in case of I-TYPE
        memory_wr_data = rs2_fwd_data; // Pass this value to the next stages unchanged. It will be used as the data value to the store instruction
        op_b = use_imm ? imm : rs2_fwd_data;

    end


    // The data to be written to the CSR address depending on if csrrw or csrrs
    assign csr_wr_data = csr_rw ? op_a : (op_a | csr_rd_data);

    riscv_regfile riscv_regfile_inst(
        .clk(clk),
        .rst(rst),
        .wr_en(wb_reg_wr_en),
        .rs1_addr(rs1_addr), // Read port 1 address
        .rs2_addr(rs2_addr), // Read port 2 address
        .rd_addr(wb_rd_addr), // Write address
        .rd_data(wb_data), // Write data
        .rs1_data(rs1_data), // Read port 1 data
        .rs2_data(rs2_data) // Read port 2 data
    );

    riscv_alu riscv_alu_inst(
        .op(exec_op), // Opcode for the operation to be performed
        .a(op_a), // First operand
        .b(op_b), // Second operand
        .result(alu_result), 
        .zero(zero) // 1-bit flag - High when result==0 - Used by branch insn
    );

    riscv_mul riscv_mul_inst(
        .clk(clk),
        .rst(rst),
        .start(mul_start),
        .op_a(op_a),
        .op_b(op_b),
        .op(exec_op),
        .result(mul_result),
        .busy(mul_busy)
    );

    always_comb begin
        unique case(1'b1)
            csr_rd_en:  exec_result = csr_rd_data;
            mul_to_reg: exec_result = mul_result;
            default:    exec_result = alu_result; // Default case is when result_src==0 and the ALU result takes priority           
        endcase
    end


endmodule

