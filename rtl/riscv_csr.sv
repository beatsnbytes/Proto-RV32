// riscv_csr.sv
// Control and Status Register (CSR) file for the RISC-V processor
// Week14 - Adding CSRs to the RISC-V processor

module riscv_csr (
    input logic clk,
    input logic rst,
    input logic [11:0] csr_addr,
    input logic csr_wr_en,
    input logic [31:0] csr_wr_data,
    output logic [31:0] csr_rd_data
);

    logic [31:0] csr_regs [4095:0]; // 16 32-bit csr registers mepc, mcause, mtvec

    logic [31:0] mcycle; // Low 32-bits of the cycle counter
    logic [31:0] mcycleh; // High 32-bits of the cycle counter
    logic [31:0] mstatus;

    // Combinational Reads
    always_comb begin
        case (csr_addr)
            12'hB00: csr_rd_data = mcycle;        // mcycle low word
            12'hB80: csr_rd_data = mcycleh;       // mcycle high word
            default: csr_rd_data = 32'b0;         // unimplemented -> read as 0 (or trap, later)
        endcase
    end

    // Sequential writes
    always_ff @(posedge clk) begin
        if (rst) begin
            mcycle  <= 32'b0;
            mcycleh <= 32'b0;
        end else begin
            // Auto-behaviors first (e.g. cycle counter always increments)
            {mcycleh, mcycle} <= {mcycleh, mcycle} + 1;   // 64-bit increment every cycle

            // Then explicit writes (override the auto-behavior if written)
            if (csr_wr_en) begin
                case (csr_addr)
                    12'hB00: mcycle  <= csr_wr_data;
                    12'hB80: mcycleh <= csr_wr_data;
                    default: ; // unimplemented -> ignore write (or trap, later)
                endcase
            end
        end
    end

endmodule