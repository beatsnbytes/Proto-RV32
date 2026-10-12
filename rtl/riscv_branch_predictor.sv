//riscv_branch_predictor.sv
// Branch predictor for the RISCV-32 core


module riscv_branch_predictor #(
    parameter BHT_SIZE = 64,
    parameter BTB_SIZE = 64
)(
    //TODO rename the signals for easier understanding
    input logic clk,
    input logic rst,
    input logic [31:0] pc,    // It is the IF PC
    input logic [31:0] update_pc,
    input logic is_branch, // 0 = JAL/JALR, 1=BNE, BNEQ etc
    input logic [31:0] resolution_target, 
    input logic resolution_taken,
    output logic [31:0] prediction_target,
    output logic prediction_taken
);

    localparam BHT_PC_IDX_WIDTH = $clog2(BHT_SIZE) + 2; //Add 2 bits since the indexing leaves 2 LSB out since instructions are byte addressed
    localparam BTB_PC_IDX_WIDTH = $clog2(BTB_SIZE) + 2; //Add 2 bits since the indexing leaves 2 LSB out since instructions are byte addressed

    localparam BTB_TAG_WIDTH = 32 - BTB_PC_IDX_WIDTH; // TODO probably dont need all MSB's. Which ones? Resizing will make comparator smaller. IMEM size will dictate that probably
    logic [1:0] bht [BHT_SIZE-1 : 0];
    logic [BHT_PC_IDX_WIDTH-1 :2] bht_index_to_update;
    logic [BTB_PC_IDX_WIDTH-1 :2] btb_index_to_update;
    logic [BTB_TAG_WIDTH-1 : 0] update_btb_tag;
    logic [BHT_PC_IDX_WIDTH-1 :2] pc_sized_to_bht_index;
    logic [BTB_PC_IDX_WIDTH-1 :2] pc_sized_to_btb_index;
    logic [BTB_TAG_WIDTH-1 : 0] btb_tag_from_pc;
    logic bht_taken;
    logic btb_hit;
    logic is_jump; // The instruction is either JAL or JALR, so should be allways taken
    // logic is_branch;

    typedef enum logic [1:0] { // Struct that defines instruction types
        BTB_BRANCH = 2'b00,
        BTB_JAL = 2'b01,
        BTB_JALR = 2'b10
    } btb_type_t;

    typedef struct packed {
        logic valid;
        logic [BTB_TAG_WIDTH-1:0] tag;
        logic [31:0] target;
        logic instr_type; // 0 = JAL/JALR, 1=BNE, BNEQ etc
    } btb_entry_t;

    btb_entry_t btb [BTB_SIZE];

    
    assign bht_index_to_update = update_pc[BHT_PC_IDX_WIDTH-1 : 2]; // Size the pc acordingly to index the BHT 
    assign btb_index_to_update = update_pc[BTB_PC_IDX_WIDTH-1 : 2]; // Size the pc acordingly to index the BTB

    // The update index and tag coming from EX
    assign update_btb_tag = update_pc[31 : (32 - BTB_TAG_WIDTH)];

    assign pc_sized_to_bht_index = pc[BHT_PC_IDX_WIDTH-1 : 2];
    assign pc_sized_to_btb_index = pc[BTB_PC_IDX_WIDTH-1 : 2];

    assign btb_tag_from_pc =  pc[31 : (32 - BTB_TAG_WIDTH)]; // Extract the btb tag from the IF PC

    // Combinational prediction according to the pc as index and the BHT's value. JAL & JALR always produce taken
    assign bht_taken = (bht[pc_sized_to_bht_index] >= 2'b10) ? 1'b1 : 1'b0;

    // Combinationally produce predicted target
    assign btb_hit = btb[pc_sized_to_btb_index].valid && (btb_tag_from_pc == btb[pc_sized_to_btb_index].tag); // This PC is a known branch
    assign is_jump = btb[pc_sized_to_btb_index].instr_type == 1'b0;

    assign prediction_taken = (btb_hit && (bht_taken || is_jump)); // I should only take the prediction if there is actually one (on BTB hit)
                                                                   // since I dont put JAL/R in BHT I guard the control signal accordingly

    // TODO In the case we get BHT entry from another instr (aliasing) then we might hit on not taken for first iteration. Can we avoid it?
    assign prediction_target = btb[pc_sized_to_btb_index].target; // Target is whatever is in the BTB

    // Update BHT
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=(BHT_SIZE -1); i++) begin
                bht[i] <= 2'b10; // Initialize with 'weakly taken'.
            end            
        end else if (is_branch) begin
            // Only branches update BHT. JAL/R dont pollute in BHT
            if (resolution_taken) begin
                    bht[bht_index_to_update] <= (bht[bht_index_to_update]==2'b11) ? 2'b11 : (bht[bht_index_to_update] + 1'b1);
            end else begin
                    bht[bht_index_to_update] <= (bht[bht_index_to_update]==2'b00) ? 2'b00 : (bht[bht_index_to_update] - 1'b1);
            end  
        end
    end

    // Update BTB
    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=0; i<=(BTB_SIZE -1); i++) begin
                btb[i] <= '{valid:1'b0, tag:'0, target:'0, instr_type:1'b1}; // Initialize with branch instruction type
            end           
        end else begin
            if (resolution_taken) begin
                btb[btb_index_to_update] <= '{valid: 1'b1, tag: update_btb_tag , target: resolution_target, instr_type: is_branch} ; 
            end  
        end
    end
endmodule



