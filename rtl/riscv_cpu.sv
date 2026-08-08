// riscv_cpu.sv
// The top level module that connects fetch&decode with execute
// Week10 - Towards a simple RISC-V processor

module riscv_cpu (
    input logic clk,
    input logic rst,
    output logic [31:0] pc,
    output logic [31:0] exec_result,
    output logic zero
);

    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [31:0] imm;
    logic [3:0] exec_op;
    logic reg_wr_en;
    logic [31:0] instr;
    logic use_imm;
    logic pc_src;
    logic [2:0] func3;
    logic branch;

    logic memory_read, memory_write, memory_to_reg;
    logic [31:0] dmem [255:0]; // 1KB data memory
    logic [31:0] memory_load_data; // Data read from memory
    logic [31:0] wb_data; // writeback data - ALU or memory

    logic [31:0] memory_wr_data;

    // Signals for the EX pipeline register
    logic [4:0] ex_rs1_addr, ex_rs2_addr;
    logic [4:0] ex_rd_addr;
    logic [31:0] ex_imm;
    logic [3:0] ex_exec_op;
    logic ex_reg_wr_en;
    logic ex_use_imm;
    logic ex_memory_read;
    logic ex_memory_write;
    logic ex_memory_to_reg;
    logic ex_branch;
    logic [2:0] ex_func3;
    logic [31:0] ex_pc;

    logic fwd_mem_rs1, fwd_mem_rs2;
    logic [1:0] fwd_to_rs1, fwd_to_rs2;

    logic [31:0] mem_exec_result;
    logic mem_memory_to_reg;
    logic [4:0] mem_rd_addr;
    logic mem_reg_wr_en;
    logic mem_memory_write; 
    logic [31:0] mem_memory_wr_data;

    logic branch_stall, mul_stall;
    logic mul_start, mul_busy;
    logic mul_done;

    logic ex_mul_start;
    logic real_start;
    logic load_bubble;

    // CSR related
    logic [31:0] csr_wr_data;
    logic [31:0] csr_rd_data;
    logic [31:0] fwd_csr_rd_data;
    logic [31:0] mem_csr_wr_data;
    logic csr_rd_en;
    logic ex_csr_rd_en;
    logic csr_rw;
    logic ex_csr_rw;
    logic csr_wr_en;
    logic ex_csr_wr_en;
    logic mem_csr_wr_en;
    logic [11:0] csr_addr;
    logic [1:0] ex_csr_addr;
    logic [1:0] mem_csr_addr;
    logic fwd_csr;

    //MEM pipeline registers & signals
    logic [31:0] mem_data;
    logic mem_stall;
    logic cache_operation_done;
    logic mem_memory_read;

    // WB pipeline registers
    logic [31:0] wb_exec_result;
    logic wb_memory_to_reg;  
    logic [4:0] wb_rd_addr;
    logic wb_reg_wr_en; 
    logic [31:0] wb_csr_wr_data;
    logic wb_csr_wr_en;
    logic [1:0] wb_csr_addr;  
    logic wb_memory_write; 
    logic [31:0] wb_memory_wr_data;
    logic fwd_wb_rs1, fwd_wb_rs2;
    logic [31:0] wb_memory_load_data;

    logic [31:0] mem_pc, wb_pc;
    


    // Pipeline stall for mul result waiting 
    assign mul_stall = ((mul_start || mul_busy) && !mul_done); 

    // Combinational logic for the source of the pc. Either from branch instr or simple pc+4 -- 0  goes to pc+4 -- 1 source is from branch
    assign pc_src = ex_branch && ((ex_func3 == 3'b000 && zero) || (ex_func3 == 3'b001 && !zero));

    always_ff @(posedge clk) begin
        branch_stall <= pc_src;
    end

    always_ff @(posedge clk) begin
        real_start <= (((exec_op == 4'hA) || (exec_op == 4'hB)) && !mul_busy && !mul_done) ? 1'b1 : 1'b0;
    end


    // Compute next pc
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;
        end else if (pc_src) begin
            pc <= ex_pc + ex_imm;
        end else if (branch_stall || mul_stall || load_bubble) begin
            pc <= pc;
        end else begin
            pc <= pc + 32'd4;
        end
    end

    


    always_ff @(posedge clk) begin
        if(rst || pc_src) begin
            ex_rs1_addr <= 5'b0;
            ex_rs2_addr <= 5'b0;
            ex_rd_addr <= 5'b0;
            ex_imm <= 32'b0;
            ex_exec_op <= 4'b0;
            ex_reg_wr_en <= 1'b0;
            ex_use_imm <= 1'b0;
            ex_memory_read <= 1'b0;
            ex_memory_write  <= 1'b0;
            ex_memory_to_reg <= 1'b0;
            ex_branch <= 1'b0;
            ex_func3 <= 3'b0;
            ex_csr_rd_en <= 1'b0;
            ex_csr_wr_en <= 1'b0;
            ex_csr_rw <= 1'b0;
            ex_csr_addr <= 2'b0;
        end else if (branch_stall || mul_busy || load_bubble) begin
            ex_rs1_addr <= 5'b0;
            ex_rs2_addr <= 5'b0;
            ex_rd_addr <= 5'b0;
            ex_imm <= 32'b0;
            ex_exec_op <= 4'b0;
            ex_reg_wr_en <= 1'b0;
            ex_use_imm <= 1'b0;
            ex_memory_read <= 1'b0;
            ex_memory_write  <= 1'b0;
            ex_memory_to_reg <= 1'b0;
            ex_branch <= 1'b0;
            ex_func3 <= 3'b0; 
            ex_csr_rd_en <= 1'b0;
            ex_csr_wr_en <= 1'b0;
            ex_csr_rw <= 1'b0;
            ex_csr_addr <= 2'b0;
        end else begin
            ex_rs1_addr <= rs1_addr;
            ex_rs2_addr <= rs2_addr;
            ex_rd_addr <= rd_addr;
            ex_imm <= imm;
            ex_exec_op <= exec_op;
            ex_reg_wr_en <= reg_wr_en;
            ex_use_imm <= use_imm;
            ex_memory_read <= memory_read;
            ex_memory_write  <= memory_write;
            ex_memory_to_reg <= memory_to_reg;
            ex_branch <= branch;
            ex_func3 <= func3;
            ex_pc <= pc;
            ex_csr_rd_en <= csr_rd_en;
            ex_csr_wr_en <= csr_wr_en;
            ex_csr_rw <= csr_rw;
            ex_csr_addr <= csr_addr[1:0];
        end
    end

    // Theoretically it will persist only for 1cc since when the NOPped ex register will flood EX stage then ex_memory_read=0 and load_bubble=0
    assign load_bubble = ex_memory_read && ((ex_rd_addr == rs1_addr) && (ex_rd_addr != 5'd0) || (ex_rd_addr == rs2_addr) && (ex_rd_addr != 5'd0)); // Insert an 1cc bubble if current instruction in execute is LOAD and the next instruction is dependent.
    // assign load_bubble = 1'b0;

    riscv_fetch_decode riscv_fetch_decode_inst(
        .clk(clk),
        .rst(rst),
        .pc(pc),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rd_addr(rd_addr),
        .imm(imm),
        .exec_op(exec_op),
        .reg_wr_en(reg_wr_en),
        .instr(instr),
        .use_imm(use_imm),
        .branch(branch),
        .func3(func3),
        .memory_read(memory_read),
        .memory_write(memory_write),
        .memory_to_reg(memory_to_reg),
        .mul_start(mul_start),
        .csr_wr_en(csr_wr_en), // To csr regfile directly
        .csr_rd_en(csr_rd_en), // To execute
        .csr_addr(csr_addr), // To csr regfile
        .csr_rw(csr_rw) // to Execute
    );

    // Put here the forwarding logic for the CSR instructions. 
    // If the instruction in EX stage is writing to CSR and the current instruction is reading from the same CSR, 
    // then we need to forward the data from EX/MEM pipeline register instead of reading from the CSR regfile 
    // (which will have the old value until the write happens at the end of MEM stage)
    assign fwd_csr = mem_csr_wr_en && (ex_csr_addr == mem_csr_addr); // TODO check fere for what the forwarding is and if it needs fixing
    assign fwd_csr_rd_data = fwd_csr ? mem_csr_wr_data : csr_rd_data;

    riscv_csr riscv_csr_inst (
        .clk(clk),
        .csr_wr_en(mem_csr_wr_en),
        .csr_wr_addr(mem_csr_addr), 
        .csr_wr_data(mem_csr_wr_data),
        .csr_rd_addr(ex_csr_addr),
        .hw_wr_en(1'b0),
        .hw_wr_addr(2'b0),
        .hw_wr_data(32'b0),
        .csr_rd_data(csr_rd_data)
    );

    riscv_execute riscv_execute_inst (
        .clk(clk),
        .rst(rst),
        .rs1_addr(ex_rs1_addr),
        .rs2_addr(ex_rs2_addr),
        .rd_addr(ex_rd_addr),
        .reg_wr_en(ex_reg_wr_en), // probably not used, prune it
        .use_imm(ex_use_imm),
        .exec_op(ex_exec_op),
        .imm(ex_imm),
        .mem_fwd_data(mem_exec_result), // The data forwarded by the mem stage (i.e ALU result)
        .wb_fwd_data(wb_data), // The data forwarded by the wb stage (i.e memory load results)  memory_load_data // TODO if this fixes it then this port is reduntant
        .wb_data(wb_data), // The data muxed in the WB stage (either the exec stage result or the memory load result)
        .fwd_to_rs1(fwd_to_rs1),
        .fwd_to_rs2(fwd_to_rs2),
        .wb_rd_addr(wb_rd_addr), // TODO prev mem
        .wb_reg_wr_en(wb_reg_wr_en), // prev mem
        .mul_start(real_start),
        .exec_result(exec_result),
        .zero(zero),
        .memory_wr_data(memory_wr_data),
        .mul_done(mul_done),
        .mul_busy(mul_busy),
        .csr_rd_data(fwd_csr_rd_data),
        .csr_rd_en(ex_csr_rd_en),
        .csr_rw(ex_csr_rw),
        .csr_wr_data(csr_wr_data) // The data to be wrtten to the csr
    );



    // MEM/EX pipeline register
    always_ff @(posedge clk) begin
        if (rst) begin
            mem_exec_result <= 32'b0;
            mem_memory_to_reg <= 1'b0;  
            mem_rd_addr <= 5'b0;
            mem_reg_wr_en <= 1'b0; 
            mem_csr_wr_data <= 32'b0;
            mem_csr_wr_en <= 1'b0;
            mem_csr_addr <= 2'b0;  
            mem_memory_write <= '0; 
            mem_memory_wr_data <= '0;
            mem_pc <= 32'b0;
        end else begin
            mem_exec_result <= exec_result;
            mem_memory_to_reg <= ex_memory_to_reg;
            mem_rd_addr <= ex_rd_addr;
            mem_reg_wr_en <= ex_reg_wr_en;
            mem_csr_wr_data <= csr_wr_data;
            mem_csr_wr_en <= ex_csr_wr_en;
            mem_csr_addr <= ex_csr_addr;
            mem_memory_write <= ex_memory_write; 
            mem_memory_read <= ex_memory_read; 
            mem_memory_wr_data <= memory_wr_data;
            mem_pc <= ex_pc;
        end
    end



    // Compare the current source registers with the destination register that just wrote back
    // Also the destination register should not be x0 (which is always zero) ad the wr_en should be high
    // Deciding on the execute stage result forwarding from mem back to ex. The memory result cannot be forwarded since it will only be ready in wb stage.
    assign fwd_mem_rs1 = ( (mem_reg_wr_en && !mem_memory_to_reg) && (ex_rs1_addr == mem_rd_addr) 
                    && (mem_rd_addr != 5'b0)) ? 1'b1 : 1'b0;
    assign fwd_mem_rs2 = ( (mem_reg_wr_en && !mem_memory_to_reg) && (ex_rs2_addr == mem_rd_addr) 
                    && (mem_rd_addr != 5'b0)) ? 1'b1 : 1'b0;

    assign cache_operation_done = 1'b1; // TODO placholder value that will be connected to the cache respond valid/ready handhsake logic
    assign mem_stall = (mem_memory_read || mem_memory_write) && !cache_operation_done; 

    // TODO implement a 2-phase FSM here. MEM_ACCEPT, MEM_RESPOND to handle the stalling of the cpu and the correct handling of the cpu-side valid/ready flags.

    // LOAD - combinational read from the dmem
    assign memory_load_data = dmem[mem_exec_result[9:2]]; // TODO if we stall here then the wb_data needs to wait for the result, so needs to get bubbles? but in the case of no memory instruction the ex_wb_ex result gest fed directly to wb

    // SW - synchronous write
    always_ff @(posedge clk) begin
        if (mem_memory_write) begin // Gate the memory write so unwanted values dont end up polluting the memory
            dmem[mem_exec_result[9:2]] <= mem_memory_wr_data;
        end    
    end


    // MEM/WB pipeline register
    always_ff @(posedge clk) begin
        if (rst) begin
            wb_exec_result <= 32'b0; 
            wb_memory_to_reg <= 1'b0;  
            wb_rd_addr <= 5'b0;
            wb_reg_wr_en <= 1'b0; 
            wb_csr_wr_data <= 32'b0;
            wb_csr_wr_en <= 1'b0;
            wb_csr_addr <= 2'b0;  
            wb_memory_write <= '0; 
            wb_memory_wr_data <= '0;
            wb_memory_load_data <= 32'b0;
            wb_pc <= 32'b0;
        end else begin
            wb_exec_result <= mem_exec_result;
            wb_memory_to_reg <= mem_memory_to_reg;
            wb_rd_addr <= mem_rd_addr;
            wb_reg_wr_en <= mem_reg_wr_en;
            wb_csr_wr_data <= mem_csr_wr_data;
            wb_csr_wr_en <= mem_csr_wr_en;
            wb_csr_addr <= mem_csr_addr;
            wb_memory_write <= mem_memory_write; 
            wb_memory_wr_data <= mem_memory_wr_data;
            wb_memory_load_data <= memory_load_data;
            wb_pc <= mem_pc;
        end
    end



    // Writeback MUX
    assign wb_data = wb_memory_to_reg ? wb_memory_load_data : wb_exec_result;

    // Forwarding logic for the WB stage
    assign fwd_wb_rs1 = ((ex_rs1_addr == wb_rd_addr) && (wb_rd_addr != 5'b0)) ? 1'b1 : 1'b0;
    assign fwd_wb_rs2 = ((ex_rs2_addr == wb_rd_addr) && (wb_rd_addr != 5'b0)) ? 1'b1 : 1'b0;




    // Priority encoders for the forwarding logic from mem and wb stages. When both asserted MEM wins since its latest instruction with most up-to-date value
    always_comb begin   
        fwd_to_rs1 = 2'b00; // 2-bit fwd logic 00=no_fwd
        if (fwd_mem_rs1) begin
            fwd_to_rs1 = 2'b10;
        end else if (fwd_wb_rs1) begin
            fwd_to_rs1 = 2'b11;
        end
    end

    always_comb begin
        fwd_to_rs2 = 2'b00;
        if (fwd_mem_rs2) begin
            fwd_to_rs2 = 2'b10;
        end else if (fwd_wb_rs2) begin
            fwd_to_rs2 = 2'b11;
        end
    end






endmodule