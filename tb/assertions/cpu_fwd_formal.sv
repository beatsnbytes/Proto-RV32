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
            if (riscv_cpu.fwd_mem_rs1 == 1'b1) begin // Giving priotity to the MEM stage forwarding as its happening in the hardware
                assert (riscv_cpu.riscv_execute_inst.op_a == riscv_cpu.riscv_execute_inst.mem_fwd_data);
            end else if (riscv_cpu.fwd_wb_rs1 == 1'b1) begin
                assert (riscv_cpu.riscv_execute_inst.op_a == riscv_cpu.riscv_execute_inst.wb_fwd_data);
            end else begin 
                assert (riscv_cpu.riscv_execute_inst.op_a == riscv_cpu.riscv_execute_inst.rs1_data);
            end

            if (riscv_cpu.riscv_execute_inst.use_imm == 1'b1) begin
                assert (riscv_cpu.riscv_execute_inst.op_b == riscv_cpu.riscv_execute_inst.imm);
            end else begin
                if (riscv_cpu.fwd_mem_rs2 == 1'b1) begin // Giving priotity to the MEM stage forwarding as its happening in the hardware
                    assert (riscv_cpu.riscv_execute_inst.op_b == riscv_cpu.riscv_execute_inst.mem_fwd_data);
                end else if (riscv_cpu.fwd_wb_rs2 == 1'b1) begin
                    assert (riscv_cpu.riscv_execute_inst.op_b == riscv_cpu.riscv_execute_inst.wb_fwd_data);
                end else begin 
                    assert (riscv_cpu.riscv_execute_inst.op_b == riscv_cpu.riscv_execute_inst.rs2_data);
                end
            end


            if (riscv_cpu.fwd_csr == 1'b1) begin
                assert (riscv_cpu.fwd_csr_rd_data == riscv_cpu.mem_csr_wr_data);
            end else begin
                assert (riscv_cpu.fwd_csr_rd_data == riscv_cpu.csr_rd_data);
            end
            
        end
    end

endmodule