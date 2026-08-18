// Direct Mapped L1 Cache
// 1KB, 16B per line

module direct_mapped_cache (
    input logic clk, 
    input logic rst,
    // CPU-side
    input logic cpu_req_write, // Read = 0, Write = 1
    input logic cpu_req_valid, 
    output logic cpu_req_ready,
    input logic [ADDR_WIDTH-1 : 0] cpu_addr,
    input logic [31 : 0] cpu_wdata,
    input logic [3:0] cpu_wmask,
    output logic [31 : 0] cpu_resp_data,
    output logic cpu_resp_valid,
    input logic cpu_resp_ready,
    // Main memory side
    output logic mem_req_write, // Read = 0, Write = 1
    output logic mem_req_valid,
    input logic mem_req_ready,
    output logic [ADDR_WIDTH-1 : 0] mem_addr,
    output logic [127 : 0] mem_wdata,
    input logic mem_resp_valid,
    output logic mem_resp_ready,
    input logic [127 : 0] mem_resp_data
);

    localparam int ADDR_WIDTH = 32;
    localparam int CACHE_ENTRIES = 64;
    localparam int INDEX_WIDTH = $clog2(CACHE_ENTRIES);    
    localparam int DATA_LINE_WIDTH = 128;
    localparam int OFFSET_WIDTH = $clog2(DATA_LINE_WIDTH/8);
    localparam int TAG_WIDTH = ADDR_WIDTH - (INDEX_WIDTH + OFFSET_WIDTH);
    

    logic [31 : 0] cpu_addr_r;
    logic [TAG_WIDTH-1 : 0] tag;
    logic [INDEX_WIDTH-1 : 0] index;
    logic [OFFSET_WIDTH-1 : 0] offset;

    logic [TAG_WIDTH-1 : 0] tag_r;
    logic [INDEX_WIDTH-1 : 0] index_r;
    logic [OFFSET_WIDTH-1 : 0] offset_r;


    logic hit;
    logic is_write_r;
    logic evict_line;
    logic evict_line_r;
    logic write_done;
    logic [31 : 0] cpu_wdata_r, cpu_wdata_masked_r;
    logic [3:0] cpu_wmask_r;
    logic [31:0] mask_extended_r;
 
    logic [TAG_WIDTH-1 : 0] tag_mem [CACHE_ENTRIES - 1 : 0];
    logic [DATA_LINE_WIDTH-1 : 0] data_mem [CACHE_ENTRIES - 1 : 0];
    logic [CACHE_ENTRIES - 1 : 0] valid_bit_mem;
    logic [CACHE_ENTRIES - 1 : 0] dirty_bit_mem; // Bit array showing the dirty lines

    typedef enum logic [2:0] {
        IDLE = 3'b000,
        EVICT = 3'b001,
        M_SEND_REQ = 3'b010,
        M_WAIT_RESP = 3'b011,
        WRITE = 3'b100,
        CPU_RESPOND = 3'b101
    } state_t;

    state_t current_state, next_state;

    assign tag = cpu_addr[ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index = cpu_addr[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset = cpu_addr[OFFSET_WIDTH - 1 : 0];

    assign tag_r = cpu_addr_r [ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index_r = cpu_addr_r[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset_r = cpu_addr_r[OFFSET_WIDTH - 1 : 0];

    assign hit = (tag == tag_mem[index]) && (valid_bit_mem[index]); // Hit is tag matches and the valid bit is asserted

    assign evict_line = valid_bit_mem[index] && dirty_bit_mem[index]; 

    assign mask_extended_r = { {8{cpu_wmask_r[3]}}, {8{cpu_wmask_r[2]}}, {8{cpu_wmask_r[1]}}, {8{cpu_wmask_r[0]}} };

    // Next state logic - combinational
    always_comb begin
        case (current_state)
            IDLE : next_state = (cpu_req_valid) ? (hit ? (cpu_req_write ? WRITE : CPU_RESPOND) : (evict_line ? EVICT : M_SEND_REQ)) : IDLE;
            EVICT : next_state = (mem_req_ready) ? M_SEND_REQ : EVICT;
            M_SEND_REQ : next_state = mem_req_ready ? M_WAIT_RESP : M_SEND_REQ;
            M_WAIT_RESP : next_state = mem_resp_valid ? (is_write_r ? WRITE : CPU_RESPOND) : M_WAIT_RESP;
            WRITE : next_state = write_done ? CPU_RESPOND : WRITE; 
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

        mem_wdata = '0;
        mem_req_write = 1'b0;

        if (!rst) begin
            case (current_state)
                IDLE : begin
                    cpu_req_ready = 1'b1;
                end
                EVICT : begin
                    mem_req_valid = 1'b1;
                    mem_addr = {tag_mem[index_r], index_r, offset_r}; // Construct the address of the cache line to be evicted.
                    mem_wdata = data_mem[index_r];
                    mem_req_write = 1'b1;
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
                    if (!is_write_r) begin
                        cpu_resp_data = data_mem[index_r][offset_r[OFFSET_WIDTH - 1 : OFFSET_WIDTH - 2]*32 +: 32];
                    end
                end
                default: ;
            endcase
        end
    end

    // Latch the cpu_req address for later use in MEM_REQ/RESPOND
    always_ff @(posedge clk) begin
        if (rst) begin
            cpu_addr_r <= '0;
            is_write_r <= '0;
            cpu_wdata_r <= '0;
            cpu_wmask_r <= '0;
            evict_line_r <= '0;
        end else if ((current_state == IDLE) && (cpu_req_ready && cpu_req_valid)) begin
            cpu_addr_r <= cpu_addr;
            is_write_r <= cpu_req_write;
            cpu_wdata_r <= cpu_wdata;
            cpu_wmask_r <= cpu_wmask;
            // cpu_wdata_masked_r <= cpu_wdata & mask_extended;
            evict_line_r <= evict_line;
        end
    end


    always_ff @(posedge clk) begin
        if (rst) begin
            for (int i=CACHE_ENTRIES-1; i>=0; i--) begin
                data_mem[i] <= '0;
                tag_mem[i] <= '0;
            end
            valid_bit_mem <= '0;   
            dirty_bit_mem <= '0;
            write_done <= '0;
        end else begin
            if ((current_state == CPU_RESPOND) && is_write_r) begin // We have already signaled the write is done so we deassert the value
                write_done <= 1'b0;
            end
            if ((current_state == M_WAIT_RESP) && mem_resp_valid) begin
                data_mem[index_r] <= mem_resp_data;
                tag_mem[index_r] <= tag_r;
                valid_bit_mem[index_r] <= 1'b1;
                dirty_bit_mem[index_r] <= 1'b0; // Need to overwrite with 0 in case the previous line was dirty and there was the value 1 as remnant
            end
            if ((current_state == WRITE) && (!write_done)) begin
                data_mem[index_r][offset_r[3:2]*32 +: 32] <= masked_word_written;
                // data_mem[index_r][offset_r[3:2]*32 +: 32] <= cpu_wdata_masked_r;
                dirty_bit_mem[index_r] <= 1'b1; // In a write-back memory a write to cache means dirty bit is asserted for the whole line
                write_done <= 1'b1; 
            end
        end
    end

    logic [31:0] selected_cache_line_word, selected_cache_line_word_masked, masked_word_written;
    always_comb begin : write_masked_word
    //TODO have to align the wdata with the mask!
        selected_cache_line_word = data_mem[index_r][offset_r[3:2]*32 +: 32];
        selected_cache_line_word_masked = ~mask_extended_r & selected_cache_line_word;

        cpu_wdata_masked_r = mask_extended_r & (cpu_wdata_r << {cpu_addr_r[1:0], 3'b0}); // Align the data to be written with the mask
        masked_word_written = selected_cache_line_word_masked | cpu_wdata_masked_r;
    end


endmodule

