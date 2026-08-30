// riscv_regfile.sv
// A simple 32x32 register file for RISC-V
// Week10 : Towards a simple RV32I processor - Register file

module riscv_regfile(
    input logic clk,
    input logic rst,
    input logic wr_en,
    input logic [4:0] rs1_addr, // Read port 1 address
    input logic [4:0] rs2_addr, // Read port 2 address
    input logic [4:0] rd_addr, // Write address
    input logic [31:0] rd_data, // Write data
    output logic [31:0] rs1_data, // Read port 1 data
    output logic [31:0] rs2_data // Read port 2 data
    );

    logic [31:0] regs [31:0]; // 32-bit wide - 32 entries register file

    // Read combinational block
    always_comb begin
        rs1_data = (rs1_addr == 0) ? 0 : regs[rs1_addr];
        rs2_data = (rs2_addr == 0) ? 0 : regs[rs2_addr];
    end


    // Write block
    always_ff @(posedge clk) begin
        if (rst) begin
            regs[0] <= 32'b0;
        end else if (wr_en && (rd_addr != 0)) begin
            regs[rd_addr] <= rd_data;
        end
    end

endmodule