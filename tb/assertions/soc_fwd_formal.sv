// riscv_soc_formal.sv
// Formal verification for the register file x0 register

module riscv_soc_formal;
    bind riscv_soc riscv_soc_formal_props props_inst (
        .clk(clk),
        .rst(rst)
    );
endmodule

module riscv_soc_formal_props (
    input logic clk,
    input logic rst
);

    always @(posedge clk) begin
        if (!rst) begin
            // Checking how the forwarding signals translate to forwarded values
            if (riscv_soc.riscv_cpu_inst.fwd_mem_rs1 == 1'b1) begin // Giving priotity to the MEM stage forwarding as its happening in the hardware
                assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_a == riscv_soc.riscv_cpu_inst.riscv_execute_inst.mem_fwd_data);
                else $error("op_a wrong when fwd_mem asserted. Expected MEM forwarded value");
            end else if (riscv_soc.riscv_cpu_inst.fwd_wb_rs1 == 1'b1) begin
                assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_a == riscv_soc.riscv_cpu_inst.riscv_execute_inst.wb_fwd_data);
                else $error("op_a wrong when fwd_wb asserted. Expected WB forwarded value");
            end else if (riscv_soc.riscv_cpu_inst.ex_exec_op == 5'b01100) begin // If the instruction is AUIPC
                assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_a == riscv_soc.riscv_cpu_inst.riscv_execute_inst.pc);
                else $error("op_a wrong ewhen instruction AUIPC detected. Expected pc value to be used instead");
            end else begin 
                assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_a == riscv_soc.riscv_cpu_inst.riscv_execute_inst.rs1_data);
                else $error("op_a wrong when no forwarding signal asserted. Expected register file rs1 value to be used instead");
            end

            if (riscv_soc.riscv_cpu_inst.riscv_execute_inst.use_imm == 1'b1) begin
                assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_b == riscv_soc.riscv_cpu_inst.riscv_execute_inst.imm);
                else $error("op_b wrong when use_imm asserted. Expected immediate value to be used instead");
            end else begin
                if (riscv_soc.riscv_cpu_inst.fwd_mem_rs2 == 1'b1) begin // Giving priotity to the MEM stage forwarding as its happening in the hardware
                    assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_b == riscv_soc.riscv_cpu_inst.riscv_execute_inst.mem_fwd_data);
                    else $error("op_b wrong when fwd_mem asserted. Expected MEM forwarded value");
                end else if (riscv_soc.riscv_cpu_inst.fwd_wb_rs2 == 1'b1) begin
                    assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_b == riscv_soc.riscv_cpu_inst.riscv_execute_inst.wb_fwd_data);
                    else $error("op_b wrong when fwd_wb asserted. Expected WB forwarded value");
                end else begin 
                    assert (riscv_soc.riscv_cpu_inst.riscv_execute_inst.op_b == riscv_soc.riscv_cpu_inst.riscv_execute_inst.rs2_data);
                    else $error("op_b wrong when no forwarding signal asserted. Expected register file rs2 value to be used instead");
                end
            end

            // Checking how the forwarding signals translate to selector value
            if (riscv_soc.riscv_cpu_inst.fwd_mem_rs1 == 1'b1) begin // Giving priotity to the MEM stage forwarding as its happening in the hardware
                assert (riscv_soc.riscv_cpu_inst.fwd_to_rs1 == 2'b10);
                else $error("selector signal wrong for rs1 when fwd_mem asserted. Expected 2'b10 value");
            end else if (riscv_soc.riscv_cpu_inst.fwd_wb_rs1 == 1'b1) begin
                assert (riscv_soc.riscv_cpu_inst.fwd_to_rs1 == 2'b11);
                else $error("selector signal wrong for rs1 when fwd_wb asserted. Expected 2'b11 value");
            end else begin 
                assert (riscv_soc.riscv_cpu_inst.fwd_to_rs1 == 2'b00);
                else $error("selector signal wrong for rs1 when no forwarding detected. Expected 2'b00 value");
            end

            if (riscv_soc.riscv_cpu_inst.fwd_mem_rs2 == 1'b1) begin // Giving priotity to the MEM stage forwarding as its happening in the hardware
                assert (riscv_soc.riscv_cpu_inst.fwd_to_rs2 == 2'b10);
                else $error("selector signal wrong for rs2 when fwd_mem asserted. Expected 2'b10 value");
            end else if (riscv_soc.riscv_cpu_inst.fwd_wb_rs2 == 1'b1) begin
                assert (riscv_soc.riscv_cpu_inst.fwd_to_rs2 == 2'b11);
                else $error("selector signal wrong for rs2 when fwd_wb asserted. Expected 2'b11 value");
            end else begin 
                assert (riscv_soc.riscv_cpu_inst.fwd_to_rs2 == 2'b00);
                else $error("selector signal wrong for rs2 when no forwarding detected. Expected 2'b00 value");
            end


        end
    end

endmodule