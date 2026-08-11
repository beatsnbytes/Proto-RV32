// riscv_mul.sv
// Multiplier for the RISCV-32 core
// Meek12 : implementing and integrating the multiplier

module riscv_mul(
    input logic clk,
    input logic rst,
    input logic start,
    input logic [31:0] op_a,
    input logic [31:0] op_b,
    input logic [3:0] op,
    output logic [31:0] result,
    output logic busy
);


    logic [4:0] bit_idx; // To index 32 bit positions
    logic [31:0] op_a_latched, op_b_latched;
    logic [3:0] op_latched;
    logic [63:0] running_total;

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
            IDLE: next_state = start ? COMPUTE : IDLE;
            COMPUTE: next_state = (bit_idx==5'd31) ? DONE : COMPUTE;
            DONE: next_state = IDLE; 
            default: next_state = IDLE;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            op_a_latched <= 32'b0;
            op_b_latched <= 32'b0;
            op_latched <= 4'b0;
            bit_idx <= 5'b0;
            running_total <= 64'b0;
        end else begin
            if (start && current_state==IDLE) begin
                op_a_latched <= op_a;
                op_b_latched <= op_b;
                op_latched <= op;
                bit_idx <= 5'b0;
                running_total <= 64'b0;
            end else if (current_state==COMPUTE) begin
                bit_idx <= bit_idx + 1;
                running_total <= op_b_latched[bit_idx] ? (running_total + (64'(op_a_latched) << bit_idx)) : running_total;
            end
        end
    end

    // Output logic
    always_comb begin
        result = 32'b0;
        case(current_state)
            DONE: begin
                case (op_latched)
                    4'b1010: result = running_total[31:0];
                    4'b1011: result = running_total[63:32];
                    default: result = 32'b0;
                endcase
            end
            default:;
        endcase

     busy = (current_state==IDLE && start) || (current_state==COMPUTE);
    end

endmodule