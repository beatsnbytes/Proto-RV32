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
    input logic alu_src,
    input logic [3:0] exec_op,
    input logic [31:0] imm,
    input logic [31:0] wb_data,
    input logic fwd_to_rs1, 
    input logic fwd_to_rs2,
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
    output logic [31:0] rs2_data,
    output logic mul_done,
    output logic mul_busy,

    output logic [31:0] csr_wr_data
);

    // From the regfile
    logic [31:0] rs1_data;
    logic [31:0] rs2_imm;

    logic [31:0] rs1_src_data;
    logic [31:0] rs2_src_data;
    logic [31:0] mul_result;
    logic [31:0] alu_result;
    logic [31:0] mul_result_latched;
    logic result_src; // Mux signal for selecting mul or alu result


    // MUX forwarding the wb data in rs1 in case of hazard
    assign rs1_src_data = fwd_to_rs1 ? wb_data : rs1_data;

    // MUX forwarding the wb data in rs2 in case of hazard
    assign rs2_src_data = fwd_to_rs2 ? wb_data : rs2_data;

    // MUX selecting between the immediate and the rs2_src_data in case of I-TYPE
    assign rs2_imm = alu_src ? imm : rs2_src_data ;

    // MUX selecting between result from CSR file, multiplier or ALU
    assign exec_result = csr_rd_en ? csr_rd_data : (result_src ? mul_result_latched : alu_result);

    // register to latch mul result
    always_ff @(posedge clk) begin
        if (rst) begin
           mul_result_latched <= 32'b0;
           result_src <= 1'b0;
        end else if (mul_done) begin
            mul_result_latched <= mul_result;
            result_src <= mul_done;
        end else begin
            result_src <= 1'b0;
        end
    end

    // The data to be written to the CSR address depending on if csrrw or csrrs
    assign csr_wr_data = csr_rw ? rs1_src_data : (rs1_src_data | csr_rd_data);

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
        .a(rs1_src_data), // First operand
        .b(rs2_imm), // Second operand
        .result(alu_result), 
        .zero(zero) // 1-bit flag - High when result==0 - Used by branch insn
    );

    riscv_mul riscv_mul_inst(
        .clk(clk),
        .rst(rst),
        .start(mul_start),
        .op_a(rs1_src_data),
        .op_b(rs2_imm),
        .op(exec_op),
        .result(mul_result),
        .done(mul_done),
        .busy(mul_busy)
    );

endmodule

