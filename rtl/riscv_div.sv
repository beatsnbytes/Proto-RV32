//riscv_div.sv
// Divider for the RISCV-32 core

module riscv_div (
    input logic clk,
    input logic rst,
    input logic is_div_instr,
    input logic [31:0] dividend,
    input logic [31:0] divisor,
    input logic rem_div_select,
    input logic is_signed_instr,    
    output logic [31:0] result,
    output logic busy
);


    logic [31:0] dividend_abs, divisor_abs;
    logic [31:0] dividend_input, dividend_input_latched, dividend_unchanged_latched, divisor_input, divisor_input_latched;

    logic dividend_sign, dividend_sign_latched, divisor_sign, divisor_sign_latched, quot_sign, rem_sign;

    logic rem_div_select_latched;
    logic iters_done;
    logic [4:0] counter;
    logic [64:0] remainder_quotient_combined_reg; // Remainder 33b + Quotient 32b (+1 bit for the trial subtraction sign to beunambiguous)

    logic [64:0] remainder_quotient_combined_reg_shifted;
    logic [32:0] trial_sub;
    logic trial_sub_sign;
    logic [32:0] ext_rem;
    logic [31:0] quot;
    logic [31:0] rem_result_normal, quot_result_normal, rem_result_special, quot_result_special;

    // Special cases
    logic is_divide_by_zero, is_signed_overflow, is_special_case;

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

    assign busy = (current_state==IDLE && is_div_instr) || (current_state==COMPUTE);
    assign iters_done = (counter==5'd31);

    always_comb begin : special_cases_detection
        is_divide_by_zero = (divisor == 32'b0);
        is_signed_overflow =  is_signed_instr && (dividend == 32'h80000000) && (divisor == 32'hFFFFFFFF);
        is_special_case = is_divide_by_zero || is_signed_overflow;
    end

    // Next state logic
    always_comb begin
        case(current_state)
            IDLE: next_state = is_div_instr ? COMPUTE : IDLE;
            COMPUTE: next_state = (iters_done || is_special_case) ? DONE : COMPUTE;
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    always_comb begin : generate_abs
        dividend_abs = dividend[31] ? (~dividend + 32'b1) : dividend;
        dividend_sign = dividend[31];
        divisor_abs = divisor[31] ? (~divisor + 32'b1) : divisor;
        divisor_sign = divisor[31];
    end

    always_comb begin : generate_dividen_divisor_inputs // Taking into account if DIV/REM are signed
        dividend_input = is_signed_instr ? dividend_abs : dividend;
        divisor_input = is_signed_instr ? divisor_abs : divisor;
    end

    always_ff @(posedge clk) begin
        if (rst) begin
//            dividend_input_latched <= 32'b0;
            divisor_input_latched <= 32'b0;
            rem_div_select_latched <= 1'b0;
            counter <= 5'b0;
            remainder_quotient_combined_reg <= 65'b0;
        end else begin
            if (is_div_instr && (current_state == IDLE)) begin
//                dividend_input_latched <= dividend_input;
                dividend_unchanged_latched <= dividend; // For the special case od div by zero where the rem wants the dividend (unchanged!)
                dividend_sign_latched <= dividend_sign; // Latch the sign in any case for it may be needed to be used later
                divisor_input_latched <= divisor_input;
                divisor_sign_latched <= divisor_sign;
                rem_div_select_latched <= rem_div_select;
                counter <= 5'b0;
                remainder_quotient_combined_reg <= {{33{1'b0}}, dividend_input};
            end else if ((current_state == COMPUTE) && !is_special_case) begin // Skip the computation for special cases
                if (trial_sub_sign) begin // If the trial sub was negative then "restore"
                    remainder_quotient_combined_reg <= {ext_rem, quot}; // We restore the values by saving the shifted value
                end else begin
                    remainder_quotient_combined_reg <= {trial_sub, quot[31:1], 1'b1}; // The rem gets the rem-div value and the quot[0]=1
                end               
                counter <= counter + 1;
            end 
        end
    end


    always_comb begin : compute_trial_sub // Perform the trial sub combinationally
        remainder_quotient_combined_reg_shifted = remainder_quotient_combined_reg << 1;
        ext_rem = remainder_quotient_combined_reg_shifted[64:32]; // Get the remainder bits from the combined register
        quot = remainder_quotient_combined_reg_shifted[31:0]; // Get the quotient bits from the combined register
        trial_sub = ext_rem - divisor_input_latched; // Make the trial subtraction
        trial_sub_sign = trial_sub[32];  // Get the sign of the trial subtraction
    end

    always_comb begin: special_cases_output
        quot_result_special = is_special_case ? ( is_signed_overflow ? 32'h80000000 : 32'hFFFFFFFF) : 32'b0;
        rem_result_special = is_special_case ? ( is_signed_overflow ? 32'b0 : dividend_unchanged_latched) : 32'b0;
    end

    always_comb begin : generate_quot_rem_results // According to if DIV/REM is signed/unsigned
        quot_sign = dividend_sign_latched ^ divisor_sign_latched; // Compute the quotient's sign
        quot_result_normal = is_signed_instr ? (quot_sign ? (~remainder_quotient_combined_reg[31:0] + 32'b1) : remainder_quotient_combined_reg[31:0]) : remainder_quotient_combined_reg[31:0];
        rem_sign = dividend_sign_latched; // Compute the rem's sign
        rem_result_normal = is_signed_instr ? (rem_sign ? (~remainder_quotient_combined_reg[63:32] + 32'b1) : remainder_quotient_combined_reg[63:32]) : remainder_quotient_combined_reg[63:32]; // Rem takess the dividends sign (i.e negate if dividend was negative)
        result = rem_div_select_latched ? (is_special_case ? rem_result_special : rem_result_normal) : (is_special_case ? quot_result_special : quot_result_normal); // rem_div_select==0 --> DIV , rem_div_select==0 --> REM
    end



    


endmodule