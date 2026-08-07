// riscv_cpu_formal.sv
// Formal verification for the register file x0 register

module riscv_cpu_formal;
    bind riscv_cpu riscv_cpu_formal_props props_inst (
        .clk(clk),
        .rst(rst)
    );
endmodule

module riscv_cpu_formal_props (
    input logic clk,
    input logic rst
);

    always @(posedge clk) begin
        if (!rst) begin
            if (riscv_cpu.fwd_to_rs1 == 1'b1) begin
                assert (riscv_cpu.riscv_execute_inst.rs1_src_data == riscv_cpu.riscv_execute_inst.wb_data);
            end else begin
                assert (riscv_cpu.riscv_execute_inst.rs1_src_data == riscv_cpu.riscv_execute_inst.rs1_data);
            end

            if (riscv_cpu.fwd_to_rs2 == 1'b1) begin
                assert (riscv_cpu.riscv_execute_inst.rs2_src_data == riscv_cpu.riscv_execute_inst.wb_data);
            end else begin
                assert (riscv_cpu.riscv_execute_inst.rs2_src_data == riscv_cpu.riscv_execute_inst.rs2_data);
            end

            if (riscv_cpu.fwd_csr == 1'b1) begin
                assert (riscv_cpu.fwd_csr_rd_data == riscv_cpu.mem_csr_wr_data);
            end else begin
                assert (riscv_cpu.fwd_csr_rd_data == riscv_cpu.csr_rd_data);
            end
            
        end
    end

endmodule