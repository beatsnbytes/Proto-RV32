//riscv_div.sv
// Divider for the RISCV-32 core

module riscv_div (
    input logic clk,
    input logic rst,
    input logic is_muldiv_instr,
    input logic [31:0] dividend,
    input logic [31:0] divisor,
    input logic rem_div_select,
    input logic is_instr_signed,    
    output logic [31:0] result,
    output logic busy
);

    logic [31:0] dividend_latched, divisor_latched;
    logic rem_div_select_latched;
    logic iters_done;
    logic [4:0] counter;
    logic [64:0] remainder_quotient_combined_reg; // Remainder 33b + Quotient 32b (+1 bit for the trial subtraction sign to beunambiguous)

    logic [64:0] remainder_quotient_combined_reg_shifted;
    logic [32:0] trial_sub;
    logic trial_sub_sign;
    logic [32:0] rem;
    logic [31:0] quot;

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

    // Next state logic
    always_comb begin
        case(current_state)
            IDLE: next_state = is_muldiv_instr ? COMPUTE : IDLE;
            COMPUTE: next_state = iters_done ? DONE : COMPUTE;
            DONE: next_state = IDLE;
            default:;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            dividend_latched <= 32'b0;
            divisor_latched <= 32'b0;
            rem_div_select_latched <= 1'b0;
            counter <= 5'b1;
            remainder_quotient_combined_reg <= 65'b0;
        end else begin
            //TODO leave the signedness for plan B, now execute basic algorithm for quotient + remainder
            if (is_muldiv_instr && (current_state == IDLE)) begin
                //TODO Latch the inputs
                dividend_latched <= dividend;
                divisor_latched <= divisor;
                rem_div_select_latched <= rem_div_select;
                counter <= 5'b1;
                remainder_quotient_combined_reg <= {{33{1'b0}}, dividend};
            end else if (current_state == COMPUTE) begin
                if (trial_sub_sign) begin // If the trial sub was negative then "restore"
                    remainder_quotient_combined_reg <= {rem, quot}; // We restore the values by saving the shifted value
                end else begin
                    remainder_quotient_combined_reg <= {trial_sub, quot[31:1], 1'b1}; // The rem gets the rem-div value and the quot[0]=1
                end               
                counter <= counter + 1;
            end
        end
    end



    always_comb begin // Perform the trial sub combinationally
        remainder_quotient_combined_reg_shifted = remainder_quotient_combined_reg << 1;
        rem = remainder_quotient_combined_reg_shifted[64:32]; // Get the remainder bits from the combined register
        quot = remainder_quotient_combined_reg_shifted[31:0]; // Get the quotient bits from the combined register
        trial_sub = rem - divisor_latched; // Make the trial subtraction
        trial_sub_sign = trial_sub[32];  // Get the sign of the trial subtraction
    end

    assign busy = (current_state==IDLE && is_muldiv_instr) || (current_state==COMPUTE);
    assign iters_done = (counter==5'd31);
    assign result = rem_div_select_latched ? remainder_quotient_combined_reg[31:0] : remainder_quotient_combined_reg[63:32];


endmodule