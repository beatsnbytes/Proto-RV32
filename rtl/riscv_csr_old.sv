// riscv_csr.sv
// Control and Status Register (CSR) file for the RISC-V processor
// Week14 - Adding CSRs to the RISC-V processor

module riscv_csr_old (
    input logic clk,
    input logic csr_wr_en,
    input logic [1:0] csr_wr_addr,
    input logic [31:0] csr_wr_data,
    input logic [1:0] csr_rd_addr, // 2 bits to index 3 registers
    input logic hw_wr_en,
    input logic [1:0] hw_wr_addr,
    input logic [31:0] hw_wr_data, // 2 bits to index 3 registers
    output logic [31:0] csr_rd_data
);

    logic [31:0] csr_regs [2:0]; // 3 32-bit csr registers mepc, mcause, mtvec

    // Combinational Reads
    always_comb begin 
        csr_rd_data = csr_regs[csr_rd_addr];
    end

    // Sequential Writes
    always_ff @(posedge clk) begin
        if (hw_wr_en) begin // Priority to hw write
            csr_regs[hw_wr_addr] <= hw_wr_data;
        end else if (csr_wr_en) begin
            csr_regs[csr_wr_addr] <= csr_wr_data;            
        end
    end


endmodule