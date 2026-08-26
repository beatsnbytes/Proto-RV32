// riscv_cpu.sv
// The top level module that connects fetch&decode with execute
// Week10 - Towards a simple RISC-V processor

//TODO perform a general code refactoring. bundle logic together per stage pipeline registers and reorder module instationation, seq and comb blocks where needed
module riscv_cpu #(
    parameter string IMEM_HEX_FILE = "UNSET.hex"
 )(
    input logic clk,
    input logic rst,
    //CPU-to-Cache connection
    output logic cpu_req_write, // Read = 0, Write = 1
    output logic cpu_req_valid, 
    input logic cpu_req_ready,
    output logic [31 : 0] cpu_addr,
    output logic [31 : 0] cpu_wdata,
    output logic [3:0] cpu_wmask,
    input logic [31 : 0] cpu_resp_data,
    input logic cpu_resp_valid,
    output logic cpu_resp_ready
);

    logic [4:0] rs1_addr, rs2_addr, rd_addr;
    logic [31:0] imm;
    logic [4:0] exec_op;
    logic reg_wr_en;
    logic [31:0] instr;
    logic use_imm;
    logic branch_taken;
    logic [2:0] func3;
    logic branch_instr;

    logic memory_read, memory_write, memory_to_reg;
    logic [31:0] dmem [255:0]; // 1KB data memory
    logic [31:0] memory_load_data; // Data read from memory
    logic [31:0] wb_data; // writeback data - ALU or memory

    logic [31:0] memory_wr_data;

    // Signals for the EX pipeline register
    logic [4:0] ex_rs1_addr, ex_rs2_addr;
    logic [4:0] ex_rd_addr;
    logic [31:0] ex_imm;
    logic [4:0] ex_exec_op;
    logic ex_reg_wr_en;
    logic ex_use_imm;
    logic ex_memory_read;
    logic ex_memory_write;
    logic ex_memory_to_reg;
    logic ex_branch_instr;
    logic [2:0] ex_func3;
    logic [31:0] ex_pc;
    logic [31:0] pc;
    logic [31:0] target_pc;
    logic zero;
    logic [31:0] exec_result;
    logic ex_is_jal, ex_is_jalr;

    logic fwd_mem_rs1, fwd_mem_rs2;
    logic [1:0] fwd_to_rs1, fwd_to_rs2;

    logic [31:0] mem_exec_result;
    logic mem_memory_to_reg;
    logic [4:0] mem_rd_addr;
    logic mem_reg_wr_en;
    logic mem_memory_write; 
    logic [31:0] mem_memory_wr_data;

    logic muldiv_busy;
    logic mul_done;

    logic real_start;
    logic load_use_hzrd_bubble;

    // Branch related
    logic condition_needs_zero, condition_not_needs_zero;

    // JAL/JALR related
    logic is_jal, is_jalr;

    // CSR related
    logic [31:0] csr_wr_data;
    logic [31:0] csr_rd_data;
    logic [31:0] fwd_csr_rd_data;
    logic [31:0] mem_csr_wr_data;
    logic csr_rd_en;
    logic [1:0] csr_op, ex_csr_op;
    // logic ex_csr_rd_en;
    logic csr_rw;
    logic ex_csr_rw;
    logic csr_wr_en;
    logic ex_csr_wr_en;
    logic mem_csr_wr_en;
    logic [11:0] csr_addr;  // The whole 12 bits come from the decoder
    logic [11:0] ex_csr_addr; // I hold only 4 bits at the rest of the pipeline
    logic [11:0] mem_csr_addr;
    logic is_csr, ex_is_csr;
    logic fwd_csr;

    //MEM pipeline registers & signals
    logic [31:0] mem_data;
    logic mem_stall;
    logic cache_operation_done;
    logic mem_memory_read;
    logic mem_is_jal, mem_is_jalr;
    logic [2:0] mem_func3;
    logic is_store_word, is_store_half_word, is_store_byte;
    logic is_load_word, is_load_half_word, is_load_byte, is_load_signed;
    logic [3:0] write_mask;
    logic [31:0] sized_load_data;

    // WB pipeline registers
    logic [31:0] wb_exec_result;
    logic wb_memory_to_reg;  
    logic [4:0] wb_rd_addr;
    logic wb_reg_wr_en; 
    logic [31:0] wb_csr_wr_data;
    logic wb_csr_wr_en;
    logic [11:0] wb_csr_addr;  
    logic wb_memory_write; 
    logic [31:0] wb_memory_wr_data;
    logic fwd_wb_rs1, fwd_wb_rs2;
    logic [31:0] wb_memory_load_data;
    logic [31:0] mem_pc, wb_pc;
    logic wb_is_jal, wb_is_jalr;
    logic [31:0] wb_return_address_data;
    logic [31:0] last_wb_pc;
    logic is_retired_inst_valid;

    
    // Compute next pc
    always_ff @(posedge clk) begin
        if (rst) begin
            pc <= 32'd0;                 
        end else if ( muldiv_busy || load_use_hzrd_bubble || mem_stall) begin // mem_stall wins everywhere. In the case of branch_taken alongside with mem_stall the latter will
                                                                              // win and the pc will "erroneously" show the wrong PC for the mem_stall duration. 
                                                                              // When it finalizes branch_taken will take over and put the jump pc here.
            // FREEZE - hold current value - no assignment needed                              
        end else if (branch_taken) begin
            pc <= target_pc;            
        end else begin
            pc <= pc + 32'd4;
        end
    end
    
    riscv_fetch_decode #(
        .IMEM_HEX_FILE(IMEM_HEX_FILE)
    )riscv_fetch_decode_inst(
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
        .branch_instr(branch_instr),
        .func3(func3),
        .memory_read(memory_read),
        .memory_write(memory_write),
        .memory_to_reg(memory_to_reg),
        .is_jal(is_jal), // Signal that selects to writeback/forward PC+4 
        .is_jalr(is_jalr), // Signal that selects to writeback/forward PC+4 
        .csr_addr(csr_addr), // To csr regfile 
        .is_csr(is_csr),
        .csr_wr_en(csr_wr_en), // To csr regfile directly
        .csr_op(csr_op)
    );



    always_ff @(posedge clk) begin
        if(rst) begin // TODO removed branch_taken from here because it was causing JAL/R instructions while stall to be lost in the pipeline (they werent stalling)
            ex_rs1_addr <= 5'b0;
            ex_rs2_addr <= 5'b0;
            ex_rd_addr <= 5'b0;
            ex_imm <= 32'b0;
            ex_exec_op <= 5'b0;
            ex_reg_wr_en <= 1'b0;
            ex_use_imm <= 1'b0;
            ex_memory_read <= 1'b0;
            ex_memory_write  <= 1'b0;
            ex_memory_to_reg <= 1'b0;
            ex_branch_instr <= 1'b0;
            ex_func3 <= 3'b0;
            ex_csr_addr <= 12'b0;
            ex_is_csr <= 1'b0;
            ex_csr_wr_en <= 1'b0;
            ex_csr_op <= 2'b0;
            ex_pc <= 32'b0;
            ex_is_jal <= 1'b0;
            ex_is_jalr <= 1'b0;
        end else if (mem_stall || muldiv_busy) begin
            // FREEZE - hold current values - no assignment needed here 
        end else if (load_use_hzrd_bubble || branch_taken) begin // load_use_hazard has to insert a bubble but has to have lower priority than mem_stall so we have to duplicate the zero branches.
            ex_rs1_addr <= 5'b0;
            ex_rs2_addr <= 5'b0;
            ex_rd_addr <= 5'b0;
            ex_imm <= 32'b0;
            ex_exec_op <= 5'b0;
            ex_reg_wr_en <= 1'b0;
            ex_use_imm <= 1'b0;
            ex_memory_read <= 1'b0;
            ex_memory_write  <= 1'b0;
            ex_memory_to_reg <= 1'b0;
            ex_branch_instr <= 1'b0;
            ex_func3 <= 3'b0; 
            ex_csr_addr <= 12'b0;
            ex_is_csr <= 1'b0;
            ex_csr_wr_en <= 1'b0;
            ex_csr_op <= 2'b0;
            ex_pc <= 32'b0;
            ex_is_jal <= 1'b0;
            ex_is_jalr <= 1'b0;
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
            ex_branch_instr <= branch_instr;
            ex_func3 <= func3;
            ex_pc <= pc;
            ex_csr_addr <= csr_addr; // 4 bits enough for 16 CSR registers
            ex_is_csr <= is_csr;
            ex_csr_wr_en <= csr_wr_en;
            ex_csr_op <= csr_op;
            ex_is_jal <= is_jal;
            ex_is_jalr <= is_jalr;
        end
    end

    always_comb begin: branch_logic
        target_pc = ex_is_jalr ? (exec_result & ~(32'b1)) : (ex_pc + ex_imm); // Select between (ex_pc + ex_imm) and (rs1 + imm) & ~1 coming from the ALU in the case of JALR
        condition_needs_zero = ((ex_func3==3'b000) || (ex_func3==3'b101) || (ex_func3==3'b111));
        condition_not_needs_zero = ((ex_func3==3'b001) || (ex_func3==3'b100) || (ex_func3==3'b110));
        branch_taken = ex_is_jal || ex_is_jalr || (ex_branch_instr && ((condition_needs_zero && zero) || (condition_not_needs_zero && !zero)));
    end


    // Theoretically it will persist only for 1cc since when the NOPped ex register will flood EX stage then ex_memory_read=0 and load_bubble=0
    assign load_use_hzrd_bubble = ex_memory_read && ((ex_rd_addr == rs1_addr) && (ex_rd_addr != 5'd0) || (ex_rd_addr == rs2_addr) && (ex_rd_addr != 5'd0)); // Insert an 1cc bubble if current instruction in execute is LOAD and the next instruction is dependent.

    riscv_execute riscv_execute_inst (
        .clk(clk),
        .rst(rst),
        .rs1_addr(ex_rs1_addr),
        .rs2_addr(ex_rs2_addr),
        .pc(ex_pc),
        .reg_wr_en(ex_reg_wr_en), // probably not used, prune it
        .use_imm(ex_use_imm),
        .exec_op(ex_exec_op),
        .imm(ex_imm),
        .mem_fwd_data(mem_exec_result), // The data forwarded by the mem stage (i.e ALU result)
        .wb_fwd_data(wb_data), // The data forwarded by the wb stage (i.e memory load results)  memory_load_data // TODO if this fixes it then this port is reduntant
        .wb_data(wb_data), // The data muxed in the WB stage (either the exec stage result or the memory load result)
        .fwd_to_rs1(fwd_to_rs1),
        .fwd_to_rs2(fwd_to_rs2),
        .wb_rd_addr(wb_rd_addr), 
        .wb_reg_wr_en(wb_reg_wr_en), 
        .exec_result(exec_result),
        .zero(zero),
        .memory_wr_data(memory_wr_data),
        .muldiv_busy(muldiv_busy),
        .csr_addr(ex_csr_addr),
        .is_csr(ex_is_csr),
        .csr_wr_en(ex_csr_wr_en),
        .csr_op(ex_csr_op),
        .is_retired_inst_valid(is_retired_inst_valid)
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
            mem_csr_addr <= 12'b0;  
            mem_memory_write <= '0; 
            mem_memory_wr_data <= '0;
            mem_pc <= 32'b0;
            mem_is_jal <= 1'b0;
            // mem_is_jalr <= 1'b0;
            mem_func3 <= 3'b0;
        end else if (mem_stall) begin
            // FREEZE - hold current values - no assignment needed here
        end else if (muldiv_busy) begin
            mem_exec_result <= 32'b0;
            mem_memory_to_reg <= 1'b0;  
            mem_rd_addr <= 5'b0;
            mem_reg_wr_en <= 1'b0; 
            mem_csr_wr_data <= 32'b0;
            mem_csr_wr_en <= 1'b0;
            mem_csr_addr <= 12'b0;  
            mem_memory_write <= '0; 
            mem_memory_wr_data <= '0;
            mem_pc <= 32'b0;
            mem_is_jal <= 1'b0;
            // mem_is_jalr <= 1'b0;
            mem_func3 <= 3'b0;
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
            mem_is_jal <= ex_is_jal;
            // mem_is_jalr <= ex_is_jalr;
            mem_func3 <= ex_func3;
        end
    end


    assign fwd_mem_rs1 = ( (mem_reg_wr_en && !mem_memory_to_reg) && (ex_rs1_addr == mem_rd_addr) 
                    && (mem_rd_addr != 5'b0)) ? 1'b1 : 1'b0;
    assign fwd_mem_rs2 = ( (mem_reg_wr_en && !mem_memory_to_reg) && (ex_rs2_addr == mem_rd_addr) 
                    && (mem_rd_addr != 5'b0)) ? 1'b1 : 1'b0;


    // Following FSM model that takes care of the memory access (currently cache), design stall and the respective data transfers.
    typedef enum logic[1:0] {
        IDLE = 2'b00,
        MEM_SEND_REQUEST = 2'b01,
        MEM_WAIT_RESPONSE = 2'b10
    } state_t;

    state_t current_state, next_state;

    // State transition
    always_ff @(posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always_comb begin
        case(current_state)
            IDLE: next_state = (mem_memory_read || mem_memory_write) ? MEM_SEND_REQUEST : IDLE;
            MEM_SEND_REQUEST: next_state = cpu_req_ready ? MEM_WAIT_RESPONSE : MEM_SEND_REQUEST;
            MEM_WAIT_RESPONSE: next_state = cpu_resp_valid ? IDLE : MEM_WAIT_RESPONSE;
            default: next_state = IDLE;
        endcase
    end

logic busy;
    // Output logic
    always_comb begin
        cpu_req_valid = 1'b0;
        cpu_req_write = 1'b0;
        cpu_addr = 32'b0;
        cpu_wdata = 32'b0;
        cpu_wmask = 4'b0;
        cpu_resp_ready = 1'b0;
        case(current_state)
            MEM_SEND_REQUEST: begin
                cpu_req_valid = 1'b1;
                cpu_req_write = mem_memory_write;                
                cpu_addr = mem_exec_result; // In the case of a memory instruction the computed adress comes from the output of the ALU
                cpu_wdata = mem_memory_wr_data;
                cpu_wmask = write_mask;
            end
            MEM_WAIT_RESPONSE: begin
                cpu_resp_ready = 1'b1;
            end 
            default:;
        endcase
    end
    // End of cache-related FSM model

    always_comb begin:handle_sub_word_stores
        is_store_word = (mem_func3==3'b010);
        is_store_half_word = (mem_func3==3'b001);
        is_store_byte = (mem_func3==3'b000);
    
        case(mem_func3)
            3'b010: write_mask = 4'b1111; //SW
            3'b001: write_mask = mem_exec_result[1] ? 4'b1100 : 4'b0011; // SH (upper-half), SH (lower-half)
            3'b000: write_mask = 4'b0001 << mem_exec_result[1:0]; // SB (byte3, byte2, bye1, byte0)
            default: write_mask = 4'b0000; //Default to write nothing
        endcase

    end

    // The signals below assume that in the mem_stall case all MEM register signals stay frozen so there is no need to latch any signals mid stall
    always_comb begin : handle_sub_word_loads
        is_load_word = (mem_func3==3'b010); 
        is_load_half_word = (mem_func3[0] == 1'b1);
        is_load_byte = (mem_func3[0] == 1'b0) && !(mem_func3[1] == 1'b1); // Avoid matching the case of LW func3=010
        is_load_signed = (mem_func3[2] == 1'b0) && !(mem_func3[1] == 1'b1);
        sized_load_data = 32'b0;

        if (is_load_word) begin
            sized_load_data = cpu_resp_data;
        end else if (is_load_half_word) begin // LH
            if (mem_exec_result[1]==1'b0) begin // the lower half
                sized_load_data = is_load_signed ? { {16{cpu_resp_data[15]}}, cpu_resp_data[15:0] } : { 16'b0, cpu_resp_data[15:0] }; 
            end else begin // the upper half
                sized_load_data = is_load_signed ? { {16{cpu_resp_data[31]}}, cpu_resp_data[31:16] } : { 16'b0, cpu_resp_data[31:16] }; 
            end
        end else if (is_load_byte) begin // LB
            case(mem_exec_result[1:0])
                2'b00: sized_load_data = is_load_signed ? { {24{cpu_resp_data[7]}}, cpu_resp_data[7:0] } : { 24'b0, cpu_resp_data[7:0] };
                2'b01: sized_load_data = is_load_signed ? { {24{cpu_resp_data[15]}}, cpu_resp_data[15:8] } : { 24'b0, cpu_resp_data[15:8] };
                2'b10: sized_load_data = is_load_signed ? { {24{cpu_resp_data[23]}}, cpu_resp_data[23:16] } : { 24'b0, cpu_resp_data[23:16] };
                2'b11: sized_load_data = is_load_signed ? { {24{cpu_resp_data[31]}}, cpu_resp_data[31:24] } : { 24'b0, cpu_resp_data[31:24] };
                default: sized_load_data = 32'b0;
            endcase
        end
    end

    assign mem_stall = (mem_memory_read || mem_memory_write) && !(cpu_resp_ready && cpu_resp_valid); // Safe only while cache handshake outputs are registered/glitch-free (Moore)
    assign memory_load_data = (cpu_resp_ready && cpu_resp_valid) ? sized_load_data : 32'b0;

    // MEM/WB pipeline register
    always_ff @(posedge clk) begin
        if (rst || mem_stall) begin
            wb_exec_result <= 32'b0; 
            wb_memory_to_reg <= 1'b0;  
            wb_rd_addr <= 5'b0;
            wb_reg_wr_en <= 1'b0; 
            wb_csr_wr_data <= 32'b0;
            wb_csr_wr_en <= 1'b0;
            wb_memory_write <= '0; 
            wb_memory_wr_data <= '0;
            wb_memory_load_data <= 32'b0;
            wb_pc <= 32'b0;
            wb_is_jal <= 1'b0;
            // wb_is_jalr <= 1'b0;
        end else begin
            wb_exec_result <= mem_exec_result;
            wb_memory_to_reg <= mem_memory_to_reg;
            wb_rd_addr <= mem_rd_addr;
            wb_reg_wr_en <= mem_reg_wr_en;
            wb_csr_wr_data <= mem_csr_wr_data;
            wb_csr_wr_en <= mem_csr_wr_en;
            // wb_csr_addr <= mem_csr_addr;
            wb_memory_write <= mem_memory_write; 
            wb_memory_wr_data <= mem_memory_wr_data;
            wb_memory_load_data <= memory_load_data;
            wb_pc <= mem_pc;
            wb_is_jal <= mem_is_jal;
            // wb_is_jalr <= mem_is_jalr;
        end
    end


    always_ff @(posedge clk) begin : minstret_signal_generation
        if (rst) begin
            last_wb_pc <= 32'b0;
        end else begin
            last_wb_pc <= wb_pc;
        end
    end
    assign is_retired_inst_valid = ((last_wb_pc != wb_pc) && (last_wb_pc != 32'b0)); // If the PC changed and its not a NOP


    always_comb begin : writeback_logic
        // Writeback MUX (Decide between JAL, ALU and memory results) 
        wb_return_address_data = wb_pc + 32'd4; //TODO maybe capture the normal PC+4 and carry it down here?
        wb_data = wb_is_jal ? wb_return_address_data 
                            : (wb_memory_to_reg ? wb_memory_load_data 
                            :  wb_exec_result); // In the case of jalr or nor jal and not memory to reg then we write back the execute stages result

        // Forwarding logic for the WB stage
        fwd_wb_rs1 = ((ex_rs1_addr == wb_rd_addr) && (wb_rd_addr != 5'b0)) ? 1'b1 : 1'b0;
        fwd_wb_rs2 = ((ex_rs2_addr == wb_rd_addr) && (wb_rd_addr != 5'b0)) ? 1'b1 : 1'b0;


        // Priority encoders for the forwarding logic from mem and wb stages. When both asserted MEM wins since its latest instruction with most up-to-date value
        fwd_to_rs1 = 2'b00; // 2-bit fwd logic 00=no_fwd
        if (fwd_mem_rs1) begin
            fwd_to_rs1 = 2'b10;
        end else if (fwd_wb_rs1) begin
            fwd_to_rs1 = 2'b11;
        end

        fwd_to_rs2 = 2'b00;
        if (fwd_mem_rs2) begin
            fwd_to_rs2 = 2'b10;
        end else if (fwd_wb_rs2) begin
            fwd_to_rs2 = 2'b11;
        end

    end
   






endmodule