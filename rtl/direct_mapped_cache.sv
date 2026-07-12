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

    logic [31 : 0] cpu_addr_r;
    logic [TAG_WIDTH-1 : 0] tag;
    logic [INDEX_WIDTH-1 : 0] index;
    logic [OFFSET_WIDTH-1 : 0] offset;

    logic [TAG_WIDTH-1 : 0] tag_r;
    logic [INDEX_WIDTH-1 : 0] index_r;
    logic [OFFSET_WIDTH-1 : 0] offset_r;


    logic hit;
 
    logic [TAG_WIDTH-1 : 0] tag_mem [CACHE_ENTRIES - 1 : 0];
    logic [DATA_LINE_WIDTH-1 : 0] data_mem [CACHE_ENTRIES - 1 : 0];
    logic [CACHE_ENTRIES - 1 : 0] valid_bit_mem;

    typedef enum logic [1:0] {
        IDLE = 2'b00,
        M_SEND_REQ = 2'b01,
        M_WAIT_RESP = 2'b10,
        CPU_RESPOND = 2'b11
    } state_t;

    state_t current_state, next_state;

    assign tag = cpu_addr[ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index = cpu_addr[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset = cpu_addr[OFFSET_WIDTH - 1 : 0];

    assign tag_r = cpu_addr_r [ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index_r = cpu_addr_r[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset_r = cpu_addr_r[OFFSET_WIDTH - 1 : 0];

    assign hit = (tag == tag_mem[index]) && (valid_bit_mem[index]); // Hit is tag matches and the valid bit is asserted

    // Next state logic - combinational
    always_comb begin
        case (current_state)
            IDLE : next_state = (cpu_req_valid) ? (hit ? CPU_RESPOND : M_SEND_REQ) : IDLE;
            M_SEND_REQ : next_state = mem_req_ready ? M_WAIT_RESP : M_SEND_REQ;
            M_WAIT_RESP : next_state = mem_resp_valid ? CPU_RESPOND : M_WAIT_RESP;
            CPU_RESPOND: next_state = cpu_resp_ready ? IDLE : CPU_RESPOND; 
            default : next_state = current_state;
        endcase
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
        if (!rst) begin
            case (current_state)
                IDLE : begin
                    cpu_req_ready = 1'b1;
                end
                M_SEND_REQ : begin
                    mem_req_valid = 1'b1;
                    mem_addr = {cpu_addr_r[31:4], 4'b0};
                end
                M_WAIT_RESP : begin
                    mem_resp_ready = 1'b1;
                end
                CPU_RESPOND : begin
                    cpu_resp_valid = 1'b1;
                    cpu_resp_data = data_mem[index_r][offset_r[OFFSET_WIDTH - 1 : OFFSET_WIDTH - 2]*32 +: 32];
                end
            endcase
        end
    end

    // Latch the cpu_req address for later use in MEM_REQ/RESPOND
    always_ff @(posedge clk) begin
        if (rst) begin
            cpu_addr_r <= '0;
        end else if ((current_state == IDLE) && (cpu_req_ready && cpu_req_valid)) begin
            cpu_addr_r <= cpu_addr;
        end
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=CACHE_ENTRIES-1; i>=0; i--) begin
                data_mem[i] <= '0;
                tag_mem[i] <= '0;
            end
            valid_bit_mem <= '0;    
        end else begin
            if ((current_state == M_WAIT_RESP) && mem_resp_valid) begin
                data_mem[index_r] <= mem_resp_data;
                tag_mem[index_r] <= tag_r;
                valid_bit_mem[index_r] <= 1'b1;
            end
        end
    end


endmodule