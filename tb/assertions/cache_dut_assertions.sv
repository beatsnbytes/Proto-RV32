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
    input logic [3:0] current_state
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


    // 1. CPU response holds stable until accepted (ready/valid rule)
    ap_cpu_resp_hold: assert property (@(posedge clk) disable iff (rst)
        (cpu_resp_valid && !cpu_resp_ready) |=> (cpu_resp_valid && $stable(cpu_resp_data)))
        else $error("cpu_resp_valid/data not held stable until cpu_resp_ready");

    // // 2. Memory request holds stable until accepted
    // ap_mem_req_hold: assert property (@(posedge clk) disable iff (rst)
    //     (mem_req_valid && !mem_req_ready) |=> (mem_req_ready && $stable(mem_addr)))
    //     else $error("mem_req_valid/data not held stable until mem_req_ready");

    // // 3. cpu_req_ready only asserted in IDLE
    // ap_cpu_req_ready: assert property (@(posedge clk) disable iff (rst)
    //     cpu_req_ready |-> (current_state == IDLE))
    //     else $error("cpu_req_ready asserted outside IDLE");

    // // 4. Refill (mem response accepted) only in M_WAIT_RESP
    // ap_refill: assert property (@(posedge clk) disable iff (rst)
    //     (mem_resp_ready && mem_resp_valid) |-> (current_state == M_WAIT_RESP))
    //     else $error("mem response accepted outside M_WAIT_RESP");

endmodule

// ---- Bind the checker into the DUT ----
// This attaches cache_assertions to every instance of direct_mapped_cache,
// wiring the checker's ports to the DUT's internal signals by name.
// bind direct_mapped_cache cache_assertions u_cache_assertions (.*); // TODO check if it works
bind direct_mapped_cache cache_assertions u_cache_assertions (
    .clk(clk),
    .rst(rst),
    .cpu_req_write(cpu_req_write),
    .cpu_req_flush(cpu_req_flush),
    .flush_mode(flush_mode),
    .cpu_req_valid(cpu_req_valid),
    .cpu_req_ready(cpu_req_ready),
    .cpu_addr(cpu_addr),
    .cpu_wdata(cpu_wdata),
    .cpu_wmask(cpu_wmask),
    .cpu_resp_data(cpu_resp_data),
    .cpu_resp_valid(cpu_resp_valid),
    .cpu_resp_ready(cpu_resp_ready),
    .mem_req_write(mem_req_write),
    .mem_req_valid(mem_req_valid),
    .mem_req_ready(mem_req_ready),
    .mem_addr(mem_addr),
    .mem_wdata(mem_wdata),
    .mem_resp_valid(mem_resp_valid),
    .mem_resp_ready(mem_resp_ready),
    .mem_resp_data(mem_resp_data),
    .current_state(current_state)
);
