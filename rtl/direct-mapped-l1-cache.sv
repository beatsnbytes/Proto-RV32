// Direct Mapped L1 Cache
// 1KB, 16B per line

module direct_mapped_cache (
    input logic clk, 
    input logic rst,
    // CPU-side
    input logic cpu_req_valid, 
    output logic cpu_req_ready,
    input logic [31 : 0] cpu_addr,
    output logic [31 : 0] cpu_resp_data,
    output logic cpu_resp_valid,
    input logic cpu_resp_ready,
    // Main memory side
    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic [31 : 0] mem_addr,
    input logic mem_resp_valid,
    output logic mem_resp_ready,
    input logic [127 : 0] mem_resp_data
);

    localparam int ADDR_WIDTH = 32;
    localparam int DATA_LINE_WIDTH = 128;
    localparam int INDEX_WIDTH = 6;
    localparam int OFFSET_WIDTH = 4;
    localparam int TAG_WIDTH = ADDR_WIDTH - (INDEX_WIDTH + OFFSET_WIDTH);
    localparam int CACHE_ENTRIES = 64;

    logic [TAG_WIDTH-1 : 0] tag;
    logic [INDEX_WIDTH-1 : 0] index;
    logic [OFFSET_WIDTH-1 : 0] offset;
    logic hit;
 
    logic [TAG_WIDTH-1 : 0] tag_mem [CACHE_ENTRIES - 1 : 0];
    logic [DATA_LINE_WIDTH-1 : 0] data_mem [CACHE_ENTRIES - 1 : 0];
    logic [CACHE_ENTRIES - 1 : 0] valid_bit_mem;

    typedef enum logic {
        IDLE = 1'b0,
        MEM_REQ = 1'b1
    } state_t;

    state_t current_state, next_state;

    assign tag = cpu_addr [ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index = cpu_addr[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset = cpu_addr[OFFSET_WIDTH - 1 : 0];

    assign hit = (tag == tag_mem[index]) && (valid_bit_mem[index]); // Hit is tag matches and the valid bit is asserted

    // Next state logic - combinational
    always_comb begin
        case (current_state)
            IDLE: next_state = (cpu_req_valid) ? (hit ? IDLE : MEM_REQ) : IDLE;
            MEM_REQ: next_state = (mem_resp_valid) ? IDLE : MEM_REQ;
        endcase
    end

    always_comb begin
        
    end

    // State register - sequential
    always_ff @(posedge clk) begin
        if (rst) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Output logic - combinational (Moore: depends only on state)
    always_comb begin
        cpu_req_ready = 1'b0;
        cpu_resp_valid = 1'b0;
        mem_req_valid = 1'b0;
        mem_resp_ready = 1'b0;
        cpu_resp_data = '0;
        mem_addr = '0;
        case (current_state)
            IDLE : begin
                cpu_req_ready = 1'b1;
                if (hit) begin
                    cpu_resp_valid = 1'b1;
                    cpu_resp_data = data_mem[index][offset[OFFSET_WIDTH - 1 : OFFSET_WIDTH - 2]*32 +: 32]; 
                end else begin
                    cpu_req_ready = 1'b0;
                end
            end
            MEM_REQ : begin
                mem_req_valid = 1'b1;
                mem_resp_ready = 1'b1;
                mem_addr = cpu_addr;
                if (mem_resp_valid) begin
                    cpu_resp_data = mem_resp_data[offset[OFFSET_WIDTH - 1 : OFFSET_WIDTH - 2]*32 +: 32];
                    cpu_resp_valid = 1'b1;
                end
            end
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=CACHE_ENTRIES-1; i>=0; i--) begin
                data_mem[i] <= '0;
                tag_mem[i] <= '0;
            end
            valid_bit_mem <= '0;    
        end else begin
            if (mem_resp_valid) begin
                data_mem[index] <= mem_resp_data;
                tag_mem[index] <= tag;
                valid_bit_mem[index] <= 1'b1;
            end
        end
    end


endmodule