// riscv_cpu.sv
// The top level module that connects fetch&decode with execute
// Week10 - Towards a simple RISC-V processor

module riscv_cpu (
    input logic clk,
    input logic rst,
    output logic [31:0] pc,
    output logic [31:0] ex_result,
    output logic zero
);

    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [31:0] imm;
    logic [3:0] ex_op;
    logic reg_wr_en;
    logic [31:0] instr;
    logic alu_src;
    logic pc_src;
    logic [2:0] func3;
    logic branch;

    logic mem_read, mem_write, mem_to_reg;
    logic [31:0] dmem [255:0]; // 1KB data memory
    logic [31:0] mem_data; // Data read from memory
    logic [31:0] wb_data; // writeback data - ALU or memory

    logic [31:0] rs2_data;

    // Signals for the ID/EX pipeline register
    logic [4:0] id_ex_rs1_addr, id_ex_rs2_addr;
    logic [4:0] id_ex_rd_addr;
    logic [31:0] id_ex_imm;
    logic [3:0] id_ex_ex_op;
    logic id_ex_reg_wr_en;
    logic id_ex_alu_src;
    logic id_ex_mem_read;
    logic id_ex_mem_write;
    logic id_ex_mem_to_reg;
    logic id_ex_branch;
    logic [2:0] id_ex_func3;
    logic [31:0] id_ex_pc;

    logic fwd_a, fwd_b;

    logic [31:0] ex_wb_ex_result;
    logic ex_wb_mem_to_reg;
    logic [4:0] ex_wb_rd_addr;
    logic ex_wb_reg_wr_en;
    logic ex_wb_mem_write; //
    logic [31:0] ex_wb_rs2_data;

    logic branch_stall, mul_stall;
    logic mul_start, mul_busy;
    logic mul_done;

    logic id_ex_mul_start;
    logic real_start;

    // CSR related
    logic [31:0] csr_wr_data;
    logic [31:0] csr_rd_data;
    logic [31:0] fwd_csr_rd_data;
    logic [31:0] ex_wb_csr_wr_data;
    logic csr_rd_en;
    logic id_ex_csr_rd_en;
    logic csr_rw;
    logic id_ex_csr_rw;
    logic csr_wr_en;
    logic id_ex_csr_wr_en;
    logic ex_wb_csr_wr_en;
    logic [11:0] csr_addr;
    logic [1:0] id_ex_csr_addr;
    logic [1:0] ex_wb_csr_addr;
    logic fwd_csr;
    


    // Pipeline stall for mul result waiting 
    assign mul_stall = ((mul_start || mul_busy) && !mul_done); 

    // Combinational logic for the source of the pc. Either from branch instr or simple pc+4 -- 0  goes to pc+4 -- 1 source is from branch
    assign pc_src = id_ex_branch && ((id_ex_func3 == 3'b000 && zero) || (id_ex_func3 == 3'b001 && !zero));

    always_ff @(posedge clk) begin
        branch_stall <= pc_src;
    end

    always_ff @(posedge clk) begin
        real_start <= (((ex_op == 4'hA) || (ex_op == 4'hB)) && !mul_busy && !mul_done) ? 1'b1 : 1'b0;
    end


    // Compute next pc
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;
        end else if (pc_src) begin
            pc <= id_ex_pc + id_ex_imm;
        end else if (branch_stall || mul_stall) begin
            pc <= pc;
        end else begin
            pc <= pc + 32'd4;
        end
    end

    


    always_ff @(posedge clk) begin
        if(rst || pc_src) begin
            id_ex_rs1_addr <= 5'b0;
            id_ex_rs2_addr <= 5'b0;
            id_ex_rd_addr <= 5'b0;
            id_ex_imm <= 32'b0;
            id_ex_ex_op <= 4'b0;
            id_ex_reg_wr_en <= 1'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_func3 <= 3'b0;
            id_ex_csr_rd_en <= 1'b0;
            id_ex_csr_wr_en <= 1'b0;
            id_ex_csr_rw <= 1'b0;
            id_ex_csr_addr <= 2'b0;
        end else if (branch_stall || mul_busy) begin
            id_ex_rs1_addr <= 5'b0;
            id_ex_rs2_addr <= 5'b0;
            id_ex_rd_addr <= 5'b0;
            id_ex_imm <= 32'b0;
            id_ex_ex_op <= 4'b0;
            id_ex_reg_wr_en <= 1'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write  <= 1'b0;
            id_ex_mem_to_reg <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_func3 <= 3'b0; 
            id_ex_csr_rd_en <= 1'b0;
            id_ex_csr_wr_en <= 1'b0;
            id_ex_csr_rw <= 1'b0;
            id_ex_csr_addr <= 2'b0;
        end else begin
            id_ex_rs1_addr <= rs1_addr;
            id_ex_rs2_addr <= rs2_addr;
            id_ex_rd_addr <= rd_addr;
            id_ex_imm <= imm;
            id_ex_ex_op <= ex_op;
            id_ex_reg_wr_en <= reg_wr_en;
            id_ex_alu_src <= alu_src;
            id_ex_mem_read <= mem_read;
            id_ex_mem_write  <= mem_write;
            id_ex_mem_to_reg <= mem_to_reg;
            id_ex_branch <= branch;
            id_ex_func3 <= func3;
            id_ex_pc <= pc;
            id_ex_csr_rd_en <= csr_rd_en;
            id_ex_csr_wr_en <= csr_wr_en;
            id_ex_csr_rw <= csr_rw;
            id_ex_csr_addr <= csr_addr[1:0];
        end
    end

    // TODO implement a 2-phase FSM here. MEM_ACCEPT, MEM_RESPOND to handle the stalling of the cpu and the correct handling of the cpu-side valid/ready flags.

    // TODO we have to break the ex_wb into ex_mem that actually feed the memory and then mem_wb that get bubbles untill the memory responds with the value.
    // LOAD - combinational read from the dmem
    assign mem_data = dmem[ex_wb_ex_result[9:2]]; // TODO if we stall here then the wb_data needs to wait for the result, so needs to get bubbles? but in the case of no memory instruction the ex_wb_ex result gest fed directly to wb

    // Writeback MUX
    assign wb_data = ex_wb_mem_to_reg ? mem_data : ex_wb_ex_result;

    // SW - synchronous write
    always_ff @(posedge clk) begin
        if (ex_wb_mem_write) begin 
        // if (id_ex_mem_write) begin 
                                    // TODO we gate using the id_ex_mem signal and that forces us to use combinationally the ex_result from the ALU.
                                    // try to gate using ex_wb signal and feed the write stage the registered ex_result. 
                                    // also rs2_data comes straigh from the reg_file without being registeres. I wonder why I made this asymmetry here bewteen store and load
            // dmem[ex_result[9:2]] <= rs2_data;
            dmem[ex_wb_ex_result[9:2]] <= ex_wb_rs2_data;
        end    
    end


    // Compare the current source registers with the destination register that just wrote back
    // Also the destination register should not be x0 (which is always zero) ad the wr_en should be high
    assign fwd_a = (ex_wb_reg_wr_en && (id_ex_rs1_addr == ex_wb_rd_addr) // TODO here we should add probably && !mem_to_reg
                    && (ex_wb_rd_addr != 5'b0)) ? 1'b1 : 1'b0;
    assign fwd_b = (ex_wb_reg_wr_en && (id_ex_rs2_addr == ex_wb_rd_addr) 
                    && (ex_wb_rd_addr != 5'b0)) ? 1'b1 : 1'b0;

    // EX/WB pipeline register
    always_ff @(posedge clk) begin
        if (rst) begin
            ex_wb_ex_result <= 32'b0;
            ex_wb_mem_to_reg <= 1'b0;  
            ex_wb_rd_addr <= 5'b0;
            ex_wb_reg_wr_en <= 1'b0; 
            ex_wb_csr_wr_data <= 32'b0;
            ex_wb_csr_wr_en <= 1'b0;
            ex_wb_csr_addr <= 2'b0;  
            ex_wb_mem_write <= '0; //   
            ex_wb_rs2_data <= '0;
        end else begin
            ex_wb_ex_result <= ex_result;
            ex_wb_mem_to_reg <= id_ex_mem_to_reg;
            ex_wb_rd_addr <= id_ex_rd_addr;
            ex_wb_reg_wr_en <= id_ex_reg_wr_en;
            ex_wb_csr_wr_data <= csr_wr_data;
            ex_wb_csr_wr_en <= id_ex_csr_wr_en;
            ex_wb_csr_addr <= id_ex_csr_addr;
            ex_wb_mem_write <= id_ex_mem_write; //
            ex_wb_rs2_data <= rs2_data;
        end


    end


    riscv_fetch_decode riscv_fetch_decode_inst(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .imm(imm),
        .ex_op(ex_op),
        .reg_wr_en(reg_wr_en),
        .instr(instr),
        .alu_src(alu_src),
        .branch(branch),
        .func3(func3),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .mul_start(mul_start),
        .csr_wr_en(csr_wr_en), // To csr regfile directly
        .csr_rd_en(csr_rd_en), // To execute
        .csr_addr(csr_addr), // To csr regfile
        .csr_rw(csr_rw) // to Execute
    );

    // Put here the forwarding logic for the CSR instructions. 
    // If the instruction in EX stage is writing to CSR and the current instruction is reading from the same CSR, 
    // then we need to forward the data from EX/WB pipeline register instead of reading from the CSR regfile 
    // (which will have the old value until the write happens at the end of WB stage)
    assign fwd_csr = ex_wb_csr_wr_en && (id_ex_csr_addr == ex_wb_csr_addr);
    assign fwd_csr_rd_data = fwd_csr ? ex_wb_csr_wr_data : csr_rd_data;

    riscv_csr riscv_csr_inst (
        .clk(clk),
        .csr_wr_en(ex_wb_csr_wr_en),
        .csr_wr_addr(ex_wb_csr_addr), 
        .csr_wr_data(ex_wb_csr_wr_data),
        .csr_rd_addr(id_ex_csr_addr),
        .hw_wr_en(1'b0),
        .hw_wr_addr(2'b0),
        .hw_wr_data(32'b0),
        .csr_rd_data(csr_rd_data)
    );

    riscv_execute riscv_execute_inst (
        .clk(clk),
        .rst(rst),
        .rs1_addr(id_ex_rs1_addr),
        .rs2_addr(id_ex_rs2_addr),
        .rd_addr(id_ex_rd_addr),
        .reg_wr_en(id_ex_reg_wr_en), // probably not used, prune it
        .alu_src(id_ex_alu_src),
        .ex_op(id_ex_ex_op),
        .imm(id_ex_imm),
        .wb_data(wb_data),
        .fwd_a(fwd_a),
        .fwd_b(fwd_b),
        .wb_rd_addr(ex_wb_rd_addr),
        .wb_reg_wr_en(ex_wb_reg_wr_en),
        .mul_start(real_start),
        .ex_result(ex_result),
        .zero(zero),
        .rs2_data(rs2_data),
        .mul_done(mul_done),
        .mul_busy(mul_busy),
        .csr_rd_data(fwd_csr_rd_data),
        .csr_rd_en(id_ex_csr_rd_en),
        .csr_rw(id_ex_csr_rw),
        .csr_wr_data(csr_wr_data) // The data to be wrtten to the csr
    );

endmodule