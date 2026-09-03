// Direct Mapped L1 Cache
// 1KB, 16B per line

module direct_mapped_cache (
    input logic clk, 
    input logic rst,
    // CPU-side
    input logic cpu_req_write, // Read = 0, Write = 1
    input logic cpu_req_flush,
    input logic [2:0] flush_mode, // 010 = single address, 011 = entire cache
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
    

    logic [ADDR_WIDTH - 1 : 0] cpu_addr_r;
    
    logic [TAG_WIDTH-1 : 0] tag, tag_r;
    logic [INDEX_WIDTH-1 : 0] index, index_r, index_to_flush;
    logic [OFFSET_WIDTH-1 : 0] offset, offset_r, offset_to_flush;


    logic hit;
    logic is_write_r;
    logic evict_line;
    logic evict_line_r;
    logic write_done;
    logic [31 : 0] cpu_wdata_r, cpu_wdata_masked_r;
    logic [3:0] cpu_wmask_r;
    logic [31:0] mask_extended_r;
    logic single_address_flush, whole_cache_flush, whole_cache_flush_r;
    logic line_is_dirty, flush_line_is_dirty;
 
    logic [TAG_WIDTH-1 : 0] tag_mem [CACHE_ENTRIES - 1 : 0];
    logic [DATA_LINE_WIDTH-1 : 0] data_mem [CACHE_ENTRIES - 1 : 0];
    logic [CACHE_ENTRIES - 1 : 0] valid_bit_mem;
    logic [CACHE_ENTRIES - 1 : 0] dirty_bit_mem; // Bit array showing the dirty lines

    typedef enum logic [3:0] {
        IDLE            = 4'b0000,
        M_SEND_LOAD_REQ = 4'b0001,
        M_WAIT_LOAD_RESP= 4'b0010,
        WRITE           = 4'b0011,
        EVICT_LINE      = 4'b0100,
        M_WAIT_EVICT_RESP=4'b0101,
        FLUSH_ADDR      = 4'b0110,
        M_WAIT_FLUSH_RESP=4'b0111,
        FLUSH_ALL       = 4'b1000,
        FLUSH_ALL_NEXT  = 4'b1001,
        CPU_RESPOND     = 4'b1010
    } state_t;

    state_t current_state, next_state;

    assign tag = cpu_addr[ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index = cpu_addr[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset = cpu_addr[OFFSET_WIDTH - 1 : 0];

    assign tag_r = cpu_addr_r [ADDR_WIDTH-1 : (OFFSET_WIDTH + INDEX_WIDTH)];
    assign index_r = cpu_addr_r[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset_r = cpu_addr_r[OFFSET_WIDTH - 1 : 0];

    assign hit = (tag == tag_mem[index]) && (valid_bit_mem[index]); // Hit is tag matches and the valid bit is asserted
    assign line_is_dirty = dirty_bit_mem[index_r];

    assign flush_line_is_dirty = dirty_bit_mem[address_flush_counter]; // Is the current line-to-be-evicted dirty?
    assign address_flush_counter_shifted = address_flush_counter << 4;
    assign index_to_flush = address_flush_counter_shifted[(OFFSET_WIDTH + INDEX_WIDTH) - 1 : (OFFSET_WIDTH)];
    assign offset_to_flush = address_flush_counter_shifted[OFFSET_WIDTH - 1 : 0];

    assign evict_line = valid_bit_mem[index] && dirty_bit_mem[index]; 
    

    assign mask_extended_r = { {8{cpu_wmask_r[3]}}, {8{cpu_wmask_r[2]}}, {8{cpu_wmask_r[1]}}, {8{cpu_wmask_r[0]}} };

    assign single_address_flush = cpu_req_flush && (flush_mode == 3'b010);
    assign whole_cache_flush = cpu_req_flush && (flush_mode == 3'b011);


    // Next state logic - combinational
    always_comb begin
        case (current_state)          
            IDLE: begin
                priority case (1'b1)
                    !cpu_req_valid       : next_state = IDLE;
                    single_address_flush : next_state = FLUSH_ADDR;
                    whole_cache_flush    : next_state = FLUSH_ALL;
                    hit && cpu_req_write : next_state = WRITE;
                    hit                  : next_state = CPU_RESPOND;
                    evict_line           : next_state = EVICT_LINE;
                    default              : next_state = M_SEND_LOAD_REQ;
                endcase
            end            
            EVICT_LINE : next_state =  mem_req_ready ? M_WAIT_EVICT_RESP : EVICT_LINE;           

            M_WAIT_EVICT_RESP : next_state = mem_resp_valid ? M_SEND_LOAD_REQ : M_WAIT_EVICT_RESP; // Assert resp_ready for the store and wait for memory to ack.                                                  

            FLUSH_ADDR : next_state = !line_is_dirty    ? CPU_RESPOND :         // clean. Nothing to evict so we move back to CPU_RESPOND
                                      mem_req_ready     ? M_WAIT_FLUSH_RESP :   // dirty line and memory asserts read. Then waits on memory asserting the resp valid to ack store.
                                                        FLUSH_ADDR;             // dirty line. EVICT blocks untill memory accepts the evicted line.  

            M_SEND_LOAD_REQ : next_state = mem_req_ready ? M_WAIT_LOAD_RESP : M_SEND_LOAD_REQ;       

            M_WAIT_FLUSH_RESP : next_state = !mem_resp_valid ? M_WAIT_FLUSH_RESP :         // wait for the main memory to assert the valid
                                              whole_cache_flush_r ? FLUSH_ALL_NEXT :   // if we came here through a whole cache flush then advance to the next cache line 
                                                                    CPU_RESPOND;           // if we endede up here through a single address flush then terminate

            M_WAIT_LOAD_RESP : next_state = !mem_resp_valid  ? M_WAIT_LOAD_RESP :
                                            is_write_r       ? WRITE : 
                                                              CPU_RESPOND;
            
            FLUSH_ALL : next_state = !flush_line_is_dirty ? FLUSH_ALL_NEXT :
                                                mem_req_ready ? M_WAIT_FLUSH_RESP :
                                                                FLUSH_ALL;                                 

            FLUSH_ALL_NEXT : next_state = flush_cache_done ? CPU_RESPOND : FLUSH_ALL;

            WRITE : next_state = write_done ? CPU_RESPOND : WRITE; 

            CPU_RESPOND: next_state = cpu_resp_ready ? IDLE : CPU_RESPOND; 

            default : next_state = current_state;
        endcase
    end

    logic [ADDR_WIDTH-1 : 0] address_flush_counter, address_flush_counter_shifted; // 1 extra bit so it can hold the value CACHE ENTRIES which signals we are off the cache size and the flush is done
    logic flush_cache_done;  

    assign flush_cache_done = (address_flush_counter == $bits(address_flush_counter)'(CACHE_ENTRIES));

    always_ff @(posedge clk) begin
        if (rst) begin
            address_flush_counter <= '0;
        end else begin
            if (current_state == FLUSH_ALL_NEXT) begin
                if (flush_cache_done) begin
                    address_flush_counter <= '0;    
                end else begin
                    address_flush_counter <= address_flush_counter + 1;    
                end
            end
        end    
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
                EVICT_LINE : begin
                        mem_req_valid = 1'b1;
                        mem_addr = {tag_mem[index_r], index_r, offset_r}; // Construct the address of the cache line to be evicted.
                        mem_wdata = data_mem[index_r];
                        mem_req_write = 1'b1;
                end
                FLUSH_ADDR : begin
                    if (line_is_dirty) begin
                        mem_req_valid = 1'b1;
                        mem_addr = {tag_mem[index_r], index_r, offset_r}; // Construct the address of the cache line to be evicted.
                        mem_wdata = data_mem[index_r];
                        mem_req_write = 1'b1;
                    end // If the line is clean and I tried to evict let the transition logic hanle it
                end                
                FLUSH_ALL: begin
                    if (flush_line_is_dirty) begin
                        mem_req_valid = 1'b1;
                        mem_addr = {tag_mem[index_to_flush], index_to_flush, offset_to_flush}; // Construct the address of the cache line to be evicted.
                        mem_wdata = data_mem[index_to_flush];
                        mem_req_write = 1'b1;
                    end // If the line is clean and I tried to evict let the transition logic hanle it                     
                    
                end
                M_WAIT_EVICT_RESP: begin
                    mem_resp_ready = 1'b1;
                end
                M_WAIT_FLUSH_RESP: begin
                    mem_resp_ready = 1'b1;
                end                
                M_SEND_LOAD_REQ : begin
                    mem_req_valid = 1'b1;
                    mem_addr = {cpu_addr_r[31:4], 4'b0};
                end
                M_WAIT_LOAD_RESP : begin
                    mem_resp_ready = 1'b1;
                end
                CPU_RESPOND : begin
                    cpu_resp_valid = 1'b1;
                    if (!is_write_r) begin // in case of read operation respond with the data requested
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
            whole_cache_flush_r <= '0;
        end else if ((current_state == IDLE) && (cpu_req_ready && cpu_req_valid)) begin
            cpu_addr_r <= cpu_addr;
            is_write_r <= cpu_req_write;
            cpu_wdata_r <= cpu_wdata;
            cpu_wmask_r <= cpu_wmask;
            evict_line_r <= evict_line;
            whole_cache_flush_r <= whole_cache_flush;
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
            if ((current_state == M_WAIT_LOAD_RESP) && mem_resp_valid) begin
                data_mem[index_r] <= mem_resp_data;
                tag_mem[index_r] <= tag_r;
                valid_bit_mem[index_r] <= 1'b1;
                dirty_bit_mem[index_r] <= 1'b0; // Need to overwrite with 0 in case the previous line was dirty and there was the value 1 as remnant
            end
            if ((current_state == WRITE) && (!write_done)) begin
                data_mem[index_r][offset_r[3:2]*32 +: 32] <= masked_word_written;
                dirty_bit_mem[index_r] <= 1'b1; // In a write-back memory a write to cache means dirty bit is asserted for the whole line
                write_done <= 1'b1; 
            end
        end
    end

    logic [31:0] selected_cache_line_word, selected_cache_line_word_masked, masked_word_written;
    always_comb begin : write_masked_word
        selected_cache_line_word = data_mem[index_r][offset_r[3:2]*32 +: 32];
        selected_cache_line_word_masked = ~mask_extended_r & selected_cache_line_word;

        cpu_wdata_masked_r = mask_extended_r & (cpu_wdata_r << {cpu_addr_r[1:0], 3'b0}); // Align the data to be written with the mask
        masked_word_written = selected_cache_line_word_masked | cpu_wdata_masked_r;
    end


endmodule

