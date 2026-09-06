// cache_assertions.sv
// Concurrent assertions for direct_mapped_cache.
// Bound to the DUT so RTL stays clean. Needs --assert in Verilator.

module cache_assertions (
    input logic clk, 
    input logic rst,
    // CPU-side
    input logic cpu_req_write, // Read = 0, Write = 1
    input logic cpu_req_flush,
    input logic [2:0] flush_mode, // 010 = single address, 011 = entire cache
    input logic cpu_req_valid, 
    input logic cpu_req_ready,
    input logic [ADDR_WIDTH-1 : 0] cpu_addr,
    input logic [31 : 0] cpu_wdata,
    input logic [3:0] cpu_wmask,
    input logic [31 : 0] cpu_resp_data,
    input logic cpu_resp_valid,
    input logic cpu_resp_ready,
    // Main memory side
    input logic mem_req_write, // Read = 0, Write = 1
    input logic mem_req_valid,
    input logic mem_req_ready,
    input logic [ADDR_WIDTH-1 : 0] mem_addr,
    input logic [127 : 0] mem_wdata,
    input logic mem_resp_valid,
    input logic mem_resp_ready,
    input logic [127 : 0] mem_resp_data,
    // internal state (visible because we bind inside the DUT scope)
    input logic [3:0] current_state,
    input logic [CACHE_ENTRIES - 1 : 0] dirty_bit_mem,
    input logic [CACHE_ENTRIES - 1 : 0] valid_bit_mem,
    input logic [TAG_WIDTH-1 : 0] tag_mem [CACHE_ENTRIES - 1 : 0],
    input logic [TAG_WIDTH-1 : 0] tag_r,
    input logic is_write_r,
    input logic [INDEX_WIDTH-1 : 0] index_r, 
    input logic write_done, 
    input logic [ADDR_WIDTH-1 : 0] address_flush_counter, 
    input logic single_address_flush, 
    input logic whole_cache_flush, 
    input logic whole_cache_flush_r, 
    input logic flush_cache_done,
    input logic [DATA_LINE_WIDTH-1 : 0] data_mem [CACHE_ENTRIES - 1 : 0],
    input logic [OFFSET_WIDTH-1 : 0] offset_r
);

    // Local copies of the state encoding for readability
    localparam logic [3:0] IDLE                 = 4'b0000;
    localparam logic [3:0] M_SEND_LOAD_REQ      = 4'b0001;
    localparam logic [3:0] M_WAIT_LOAD_RESP     = 4'b0010;
    localparam logic [3:0] WRITE                = 4'b0011;
    localparam logic [3:0] EVICT_LINE           = 4'b0100;
    localparam logic [3:0] M_WAIT_EVICT_RESP    =4'b0101;
    localparam logic [3:0] FLUSH_ADDR           = 4'b0110;
    localparam logic [3:0] M_WAIT_FLUSH_RESP    =4'b0111;
    localparam logic [3:0] FLUSH_ALL            = 4'b1000;
    localparam logic [3:0] FLUSH_ALL_NEXT       = 4'b1001;
    localparam logic [3:0] CPU_RESPOND          = 4'b1010;

    localparam int ADDR_WIDTH = 32;
    localparam int CACHE_ENTRIES = 64;
    localparam int INDEX_WIDTH = $clog2(CACHE_ENTRIES);    
    localparam int DATA_LINE_WIDTH = 128;
    localparam int OFFSET_WIDTH = $clog2(DATA_LINE_WIDTH/8);
    localparam int TAG_WIDTH = ADDR_WIDTH - (INDEX_WIDTH + OFFSET_WIDTH);
    localparam int MAX_LATENCY = 30;


    logic hit_r;
    assign hit_r = (tag_r == tag_mem[index_r]) && (valid_bit_mem[index_r]);

    // 1. CPU response holds stable until accepted (ready/valid rule)
    ap_cpu_resp_hold: assert property (@(posedge clk) disable iff (rst)
        (cpu_resp_valid && !cpu_resp_ready) |=> (cpu_resp_valid && $stable(cpu_resp_data)))
        else $error("cpu_resp_valid/data not held stable until cpu_resp_ready");

    // 2. Memory request holds stable until accepted
    ap_mem_req_hold: assert property (@(posedge clk) disable iff (rst)
        (mem_req_valid && !mem_req_ready) |=> (mem_req_valid && $stable(mem_addr)))
        else $error("mem_req_valid/data not held stable until mem_req_ready");

    // 3. cpu_req_ready only asserted in IDLE
    ap_cpu_req_ready: assert property (@(posedge clk) disable iff (rst)
        cpu_req_ready |-> (current_state == IDLE))
        else $error("cpu_req_ready asserted outside IDLE");

    // 4. Refill (mem response accepted) only in M_WAIT_RESP
    ap_refill: assert property (@(posedge clk) disable iff (rst)
        (mem_resp_ready && mem_resp_valid) |-> ((current_state == M_WAIT_LOAD_RESP) || (current_state == M_WAIT_FLUSH_RESP) || (current_state == M_WAIT_EVICT_RESP) ))
        else $error("mem response accepted outside wait respond state");
    
    // 5. cpu_req_valid and cpu_resp_valid never simultaneously asserted
    ap_no_simul_assert: assert property (@(posedge clk) disable iff (rst)
        !(cpu_req_valid && cpu_resp_valid))
    else $error("cpu_req_valid asserted simultaneously with cpu_resp_valid");

    // 6. Assert the correct set of dirty_bit_mem[index] with the following 2 partial assertions
    // 6a. When dirty bit is asserted then valid bit must be asserted too
    ap_dirty_n_valid_bits_set: assert property (@(posedge clk) disable iff (rst)
        dirty_bit_mem[index_r] |-> valid_bit_mem[index_r]) //
    else $error("dirty line is not valid");    

    // 6b. Assert dirty bit when write completes
    ap_dirty_bit_set: assert property (@(posedge clk) disable iff (rst)
        $fell(write_done) |-> dirty_bit_mem[index_r])
    else $error("Write completes but dirty bit is not set");

    // 7. flush_counter == 0 when NOT in FLUSH_ALL, FLUSH_ALL_NEXT, or FLUSH_ALL_DONE    
    ap_flush_counter_value: assert property (@(posedge clk) disable iff (rst)
        (address_flush_counter == 0) |-> ( (current_state != FLUSH_ALL) || (current_state != FLUSH_ALL_NEXT)))
    else $error("Not in whole cache flush mode but flush counter is not zero");

    // 8. flush_counter never exceeds CACHE_ENTRIES - 1
    ap_flush_counter_limit: assert property (@(posedge clk) disable iff (rst)
        address_flush_counter <= (CACHE_ENTRIES))
    else $error("Flush counter value %d exceeds maximum value %d", address_flush_counter, CACHE_ENTRIES);

    // 9. single_address_flush and whole_cache_flush never simultaneously asserted
    ap_mutual_exclusion: assert property ( @(posedge clk) disable iff (rst)
        !(single_address_flush && whole_cache_flush))
    else $error("Simultaneous assertion of single and whole cache flush");

    // 10. When in EVICT_LINE state, valid_bit_mem[index_r]==1 AND dirty_bit_mem[index_r]==1
    ap_evict_state_signals: assert property (@(posedge clk) disable iff (rst)
        (current_state==EVICT_LINE) |-> valid_bit_mem[index_r] && dirty_bit_mem[index_r])
    else $error("The line to be evicted is either not valid or not dirty");

    // 11. After whole cache flush all entries must be non dirty
    ap_post_flush_dirty_state: assert property (@(posedge clk) disable iff (rst)
        flush_cache_done |-> !(|dirty_bit_mem[CACHE_ENTRIES-1 : 0]))
    else $error("Dirty bit(s) still set after whole cache flush");

    // 12. On a cache hit read, cpu_resp_data must equal data_mem[index_r]
    ap_data_integrity_on_hit: assert property (@(posedge clk) disable iff (rst)
        (!is_write_r && hit_r && (cpu_resp_valid && cpu_resp_ready)) |-> cpu_resp_data == data_mem[index_r][offset_r[OFFSET_WIDTH - 1 : OFFSET_WIDTH - 2]*32 +: 32])
    else $error(" The requested data from a cache hit do not match the cache contents");

    // 13. The cache must eventually leave any non-IDLE state
    ap_fsm_liveness: assert property (@(posedge clk) disable iff (rst)
        ((current_state != IDLE) && !whole_cache_flush_r) |-> ##[1 : MAX_LATENCY] (current_state == IDLE))
    else $error(" Stuck for over %d cc in a non IDLE fsm state", MAX_LATENCY);

endmodule

// ---- Bind the checker into the DUT ----
// This attaches cache_assertions to every instance of direct_mapped_cache,
// wiring the checker's ports to the DUT's internal signals by name.
bind direct_mapped_cache cache_assertions u_cache_assertions (.*); 

