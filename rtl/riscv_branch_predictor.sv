//riscv_branch_predictor.sv
// Branch predictor for the RISCV-32 core


module riscv_branch_predictor #(
    parameter BHT_SIZE = 64,
    parameter BTB_SIZE = 64
)(
    input logic clk,
    input logic rst,
    input logic [31:0] pc,    // It is the IF PC
    input logic [31:0] resolution_pc, 
    input logic resolution_taken,
    output logic [31:0] prediction_target,
    output logic prediction_taken
);

    localparam BHT_PC_IDX_WIDTH = $clog2(BHT_SIZE) + 2; //Add 2 bits since the indexing leaves 2 LSB out since instructions are bute addressed
    localparam BTB_PC_IDX_WIDTH = $clog2(BTB_SIZE) + 2; //Add 2 bits since the indexing leaves 2 LSB out since instructions are byte addressed

    localparam BTB_TAG_WIDTH = 32 - BTB_PC_IDX_WIDTH; // TODO probably dont need all MSB's. Which ones? Resizing will make comparator smaller. IMEM size will dictate that probably
    logic [1:0] bht [BHT_SIZE-1 : 0];
    logic [BHT_PC_IDX_WIDTH-1 :2] update_index;
    logic [BTB_TAG_WIDTH-1 : 0] update_tag;
    logic [BHT_PC_IDX_WIDTH-1 :2] pc_sized;
    logic [BTB_TAG_WIDTH-1 : 0] pc_tag;
    logic bht_taken;
    logic btb_hit;


    typedef struct packed {
        logic valid;
        logic [BTB_TAG_WIDTH-1:0] tag;
        logic [31:0] target;
    } btb_entry_t;

    btb_entry_t btb [BTB_SIZE];


    // The update index and tag coming from EX
    assign update_index = resolution_pc[BHT_PC_IDX_WIDTH-1 : 2]; // Size the pc acordingly to index the BHT
    assign update_tag = resolution_pc[31 : (32 - BTB_TAG_WIDTH)];

    assign pc_sized = pc[BHT_PC_IDX_WIDTH-1 : 2];
    assign pc_tag =  pc[31 : (32 - BTB_TAG_WIDTH)]; // Extract the btb tag from the IF PC

    // Combinationally produce the prediction according to the pc as index and the BHT's value
    assign bht_taken = (bht[pc_sized] >= 2'b10) ? 1'b1 : 1'b0;

    // Combinationally produce predicted target
    assign btb_hit = btb[pc_sized].valid && (pc_tag == btb[pc_sized].tag); // This PC is a known branch

    // Combinationally produce the outputs
    assign prediction_taken = btb_hit && bht_taken;
    assign prediction_target = btb[pc_sized].target;

    // BHT and BTB Reset and update
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=(BHT_SIZE -1); i++) begin
                bht[i] <= 2'b01;
            end
            for (int i=0; i<=(BTB_SIZE -1); i++) begin
                btb[i] <= '{valid:1'b0, tag:'0, target:'0};
            end
        end else begin
            if (resolution_taken) begin
                // TODO should I take care to update only if branch instr? gate with udate_en deending on the instr. I can because it comes from EX where I know the instr!
                    bht[update_index] <= (bht[update_index]==2'b11) ? 2'b11 : (bht[update_index] + 1'b1);
                    btb[update_index] <= '{valid: 1'b1, tag: update_tag , target: resolution_pc} ;
            end else begin
                    bht[update_index] <= (bht[update_index]==2'b00) ? 2'b00 : (bht[update_index] - 1'b1);
            end
        end
    end


    // always_ff @(posedge clk) begin
    //     // TODO reset the BTB
    //     // TODO here I have to put entry to the BTB but only if it is a branch instruction?
    // end

endmodule



