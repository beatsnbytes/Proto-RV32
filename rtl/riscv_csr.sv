// riscv_csr.sv
// Control and Status Register (CSR) file for the RISC-V processor
// Week14 - Adding CSRs to the RISC-V processor

module riscv_csr (
    input logic clk,
    input logic rst,
    input logic [11:0] csr_addr,
    input logic csr_wr_en,
    input logic [31:0] csr_wr_data,
    output logic [31:0] csr_rd_data,
    // CSR specific signals
    input logic is_retired_inst_valid
);

    logic [31:0] mcycle; // Low 32-bits of the cycle counter
    logic [31:0] mcycleh; // High 32-bits of the cycle counter
    logic [31:0] minstret; // Low 32-bits of the cycle counter
    logic [31:0] minstreth; // High 32-bits of the cycle counter

    // Combinational Reads
    always_comb begin
        case (csr_addr)
            12'hB00: csr_rd_data = mcycle;        // mcycle low word
            12'hB80: csr_rd_data = mcycleh;       // mcycle high word
            12'hB02: csr_rd_data = minstret;  
            12'hB82: csr_rd_data = minstreth;
            default: csr_rd_data = 32'b0;         // unimplemented -> read as 0 (or trap, later)
        endcase
    end

    // Sequential writes
    always_ff @(posedge clk) begin
        if (rst) begin
            mcycle  <= 32'b0;
            mcycleh <= 32'b0;
            minstret <= 32'b0;
            minstreth <= 32'b0;
        end else begin
            // Auto-behavior first 
            {mcycleh, mcycle} <= {mcycleh, mcycle} + 1;   // 64-bit increment every cycle
            {minstreth, minstret} <= (is_retired_inst_valid) ? ({minstreth, minstret} + 1) : {minstreth, minstret};

            // Then explicit writes override the auto-behavior if written
            if (csr_wr_en) begin
                case (csr_addr)
                    12'hB00: mcycle  <= csr_wr_data;
                    12'hB80: mcycleh <= csr_wr_data;
                    12'hB02: minstret <= csr_wr_data ;  
                    12'hB82: minstreth <= csr_wr_data;
                    default: ; // unimplemented -> ignore write (or trap, later)
                endcase
            end
        end
    end

endmodule