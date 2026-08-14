// riscv_mul.sv
// Multiplier for the RISCV-32 core
// Meek12 : implementing and integrating the multiplier

module riscv_mul(
    input logic clk,
    input logic rst,
    input logic is_muldiv_instr,
    input logic [31:0] op_a,
    input logic is_signed_op_a,
    input logic [31:0] op_b,
    input logic is_signed_op_b,
    input logic high_low_select,
    output logic [31:0] result,
    output logic busy
);


    logic [5:0] bit_idx; // To index 64 bit positions
    logic [63:0] op_a_latched, op_b_latched;
    logic is_signed_op_a_latched, is_signed_op_b_latched, high_low_select_latched;
    logic [127:0] running_total;
    logic iters_done;

    typedef enum logic[1:0] {
        IDLE = 2'b00,
        COMPUTE = 2'b01,
        DONE = 2'b10
    } state_t;

    state_t current_state, next_state;

    // State register
    always_ff @(posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next-state logic
    always_comb begin
        case(current_state)
            IDLE: next_state = is_muldiv_instr ? COMPUTE : IDLE;
            COMPUTE: next_state = iters_done ? DONE : COMPUTE;
            DONE: next_state = IDLE; 
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            op_a_latched <= 64'b0;
            op_b_latched <= 64'b0;
            is_signed_op_a_latched <= 1'b0;
            is_signed_op_b_latched <= 1'b0;
            high_low_select_latched <= 1'b0;
            bit_idx <= 6'b0;
            running_total <= 128'b0;
        end else begin
            if (is_muldiv_instr && current_state==IDLE) begin
                op_a_latched <= is_signed_op_a ? {{32{op_a[31]}}, op_a} : {{32{1'b0}}, op_a}; // Sign extend if its signed (i.e op[1]==1) otherwise zero extend
                is_signed_op_a_latched <= is_signed_op_a; // Need to latch the signedness for applying Baugh-Wooley correction after
                op_b_latched <= is_signed_op_b ? {{32{op_b[31]}}, op_a} : {{32{1'b0}}, op_b};
                is_signed_op_b_latched <= is_signed_op_b;
                high_low_select_latched <= high_low_select;
                bit_idx <= 6'b0;
                running_total <= 128'b0;
            end else if (current_state==COMPUTE) begin
                bit_idx <= bit_idx + 1;
                running_total <= op_b_latched[bit_idx] ? (running_total + (128'(op_a_latched) << bit_idx)) : running_total;
            end
        end
    end

    assign busy = (current_state==IDLE && is_muldiv_instr) || (current_state==COMPUTE);
    assign iters_done = (bit_idx==6'd63);
    assign result = (current_state==DONE) ? (high_low_select ? running_total[63:32] : running_total[31:0]) : 32'b0;


endmodule