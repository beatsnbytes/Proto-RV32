// riscv_execute.sv
// The execute stage of the RISC-V processor
// Week10 - Bringing it all together with the execute stage

module riscv_execute (
    input logic clk,
    input logic rst,
    // From the fetch & decode
    input logic [4:0] rs1_addr,
    input logic [4:0] rs2_addr,
    input logic [31:0] pc,
    input logic reg_wr_en,
    input logic use_imm,
    input logic [4:0] exec_op,
    input logic [31:0] imm,
    input logic [31:0] mem_fwd_data,
    input logic [31:0] wb_fwd_data,
    input logic [31:0] wb_data,
    input logic [1:0] fwd_to_rs1, 
    input logic [1:0] fwd_to_rs2,
    input logic [4:0] wb_rd_addr,
    input logic wb_reg_wr_en, 
        // ALU-related
    output logic [31:0] exec_result,
    output logic zero,
    output logic [31:0] memory_wr_data,
    output logic muldiv_busy,
    // CSR-related
    input logic [11:0] csr_addr,
    input logic is_csr,
    input logic csr_wr_en,
    input logic [1:0] csr_op,
    input logic is_retired_inst_valid
);

    // From the regfile
    logic [31:0] rs1_data;
    logic [31:0] rs2_data;
    logic [31:0] op_a;
    logic [31:0] op_b;
    logic [31:0] rs2_fwd_data;
    logic [31:0] rs1_fwd_data;
    logic use_pc;
    logic [31:0] alu_result;
    logic result_src; // Mux signal for selecting mul or alu result

    // MUL signals
    logic is_signed_op_a, is_signed_op_b;
    logic high_low_select;
    logic mul_busy;
    logic [31:0] mul_result;
    // DIV signals
    logic rem_div_select;
    logic is_signed_instr;
    logic div_busy;
    logic is_muldiv_instr;
    logic is_mul_instr;
    logic is_div_instr;
    logic [31:0] div_result;  

    logic [31:0] csr_rd_data;  
    logic write_op, set_op, clear_op;
    logic [31:0] modifier_op;
    logic [31:0] csr_wr_data;

    // MUX logic forwarding the correct value to the ALU
    always_comb begin
        case(fwd_to_rs1)
            2'b00: rs1_fwd_data = rs1_data;
            2'b10: rs1_fwd_data = mem_fwd_data;
            2'b11: rs1_fwd_data = wb_fwd_data;
            default: rs1_fwd_data = rs1_data; // Defaulting to rs1 data for the invalid value of 10
        endcase
        use_pc = (exec_op == 5'b01100); // Use the PC as op_a when AUIPC
        op_a = use_pc ? pc : rs1_fwd_data;

        case(fwd_to_rs2)
            2'b00: rs2_fwd_data = rs2_data;
            2'b10: rs2_fwd_data = mem_fwd_data;
            2'b11: rs2_fwd_data = wb_fwd_data;
            default: rs2_fwd_data = rs2_data; // Defaulting to rs2 data for the invalid value of 10
        endcase

        // MUX selecting between the immediate and the rs2_fwd_data in case of I-TYPE
        memory_wr_data = rs2_fwd_data; // Pass this value to the next stages unchanged. It will be used as the data value to the store instruction
        op_b = use_imm ? imm : rs2_fwd_data;
    end


    // The data to be written to the CSR address depending on if csrrw or csrrs
    // assign csr_wr_data = csr_rw ? op_a : (op_a | csr_rd_data);


    riscv_regfile riscv_regfile_inst(
        .clk(clk),
        .rst(rst),
        .wr_en(wb_reg_wr_en),
        .rs1_addr(rs1_addr), // Read port 1 address
        .rs2_addr(rs2_addr), // Read port 2 address
        .rd_addr(wb_rd_addr), // Write address
        .rd_data(wb_data), // Write data
        .rs1_data(rs1_data), // Read port 1 data
        .rs2_data(rs2_data) // Read port 2 data
    );


    always_comb begin: csr_modify_write
    //TODO get his directly from the decoder as a csr_op signal
        write_op = (csr_op==2'b01);
        set_op = (csr_op==2'b10);
        clear_op = (csr_op==2'b11);

        // TODO shouldsnt I use the op_a in case something gets forwarded?
        modifier_op = use_imm ? imm : op_a;
        csr_wr_data = write_op ? modifier_op
               : set_op   ? (csr_rd_data | modifier_op)
               : clear_op ? (csr_rd_data & ~modifier_op)
               : csr_rd_data;
    end


    riscv_csr riscv_csr_inst(
        .clk(clk), 
        .rst(rst),
        .csr_addr(csr_addr),
        .csr_wr_en(csr_wr_en),
        .csr_wr_data(csr_wr_data),
        .csr_rd_data(csr_rd_data),
        .is_retired_inst_valid(is_retired_inst_valid)
    );

    riscv_alu riscv_alu_inst(
        .op(exec_op), // Opcode for the operation to be performed
        .a(op_a), // First operand
        .b(op_b), // Second operand
        .result(alu_result), 
        .zero(zero) // 1-bit flag - High when result==0 - Used by branch insn
    );

    assign is_muldiv_instr = exec_op[4];
    assign muldiv_busy = mul_busy || div_busy;

    always_comb begin : derive_mul_control_signals
        is_signed_op_a = exec_op[1];
        is_signed_op_b = exec_op[0];
        high_low_select = exec_op[2];
        is_mul_instr = (exec_op[4:3]==2'b10);
    end

    riscv_mul riscv_mul_inst(
        .clk(clk),
        .rst(rst),
        .is_mul_instr(is_mul_instr),
        .op_a(op_a),
        .is_signed_op_a(is_signed_op_a),
        .op_b(op_b),
        .is_signed_op_b(is_signed_op_b),
        .high_low_select(high_low_select),
        .result(mul_result),
        .busy(mul_busy)
    );

    always_comb begin : derive_div_control_signals
        rem_div_select = exec_op[1];
        is_signed_instr = exec_op[0];
        // is_div_instr = is_muldiv_instr && exec_op[3];
        is_div_instr = (exec_op[4:3]==2'b11);
    end

    riscv_div riscv_div_inst(
        .clk(clk),
        .rst(rst),
        .is_div_instr(is_div_instr),
        .dividend(op_a),
        .divisor(op_b),
        .rem_div_select(rem_div_select),
        .is_signed_instr(is_signed_instr),
        .result(div_result),
        .busy(div_busy)
    );

    always_comb begin
        unique case(1'b1)
            is_csr:  exec_result = csr_rd_data;
            is_muldiv_instr: exec_result = is_div_instr ? div_result : mul_result;
            default:    exec_result = alu_result; // Default case is when result_src==0 and the ALU result takes priority           
        endcase
    end


endmodule

