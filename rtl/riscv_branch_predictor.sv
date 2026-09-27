//riscv_branch_predictor.sv
// Branch predictor for the RISCV-32 core


module riscv_branch_predictor #(
    parameter BHT_SIZE = 64
)(
    input logic clk,
    input logic rst,
    input logic [PC_IDX-1 :2] resolution_pc,
    input logic resolution_taken,
    input logic [PC_IDX-1 :2] prediction_pc,    
    output logic prediction_taken
);

    localparam PC_IDX = $clog2(BHT_SIZE) + 2; //Add 2 bits since the indexing leaves 2LSB out since instructions are bute addressed
    logic [1:0] bht [BHT_SIZE-1 : 0];

    // Combinationally produce the prediction according to the pc as index and the BHT's value
    assign prediction_taken = (bht[prediction_pc] >= 2'b10) ? 1'b1 : 1'b0;

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=(BHT_SIZE -1); i++) begin
                bht[i] <= 2'b01;
            end
            end else begin
                if (resolution_taken) begin
                        bht[resolution_pc] <= (bht[resolution_pc]==2'b11) ? 2'b11 : (bht[resolution_pc] + 1'b1);
                end else begin
                        bht[resolution_pc] <= (bht[resolution_pc]==2'b00) ? 2'b00 : (bht[resolution_pc] - 1'b1);
                end
            end
        end

endmodule



