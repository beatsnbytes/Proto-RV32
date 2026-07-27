// cache_assertions.sv
// Concurrent assertions for direct_mapped_cache.
// Bound to the DUT so RTL stays clean. Needs --assert in Verilator.

module cache_assertions (
    input logic         clk,
    input logic         rst,
    // CPU side
    input logic         cpu_req_valid,
    input logic         cpu_req_ready,
    input logic         cpu_resp_valid,
    input logic         cpu_resp_ready,
    input logic [31:0]  cpu_resp_data,
    // Memory side
    input logic         mem_req_valid,
    input logic         mem_req_ready,
    input logic [31:0]  mem_addr,
    input logic         mem_resp_valid,
    input logic         mem_resp_ready,
    // internal state (visible because we bind inside the DUT scope)
    input logic [2:0]   current_state
);

    // Local copies of the state encoding for readability
    localparam logic [2:0] IDLE        = 3'b000;
    localparam logic [2:0] EVICT       = 3'b001;
    localparam logic [2:0] M_SEND_REQ  = 3'b010;
    localparam logic [2:0] M_WAIT_RESP = 3'b011;
    localparam logic [2:0] WRITE       = 3'b100;
    localparam logic [2:0] CPU_RESPOND = 3'b101;

    // 1. CPU response holds stable until accepted (ready/valid rule)
    ap_cpu_resp_hold: assert property (@(posedge clk) disable iff (rst)
        (cpu_resp_valid && !cpu_resp_ready) |=> (cpu_resp_valid && $stable(cpu_resp_data)))
        else $error("cpu_resp_valid/data not held stable until cpu_resp_ready");

    // 2. Memory request holds stable until accepted
    ap_mem_req_hold: assert property (@(posedge clk) disable iff (rst)
        (mem_req_valid && !mem_req_ready) |=> (mem_req_ready && $stable(mem_addr)))
        else $error("mem_req_valid/data not held stable until mem_req_ready");

    // 3. cpu_req_ready only asserted in IDLE
    ap_cpu_req_ready: assert property (@(posedge clk) disable iff (rst)
        cpu_req_ready |-> (current_state == IDLE))
        else $error("cpu_req_ready asserted outside IDLE");

    // 4. Refill (mem response accepted) only in M_WAIT_RESP
    ap_refill: assert property (@(posedge clk) disable iff (rst)
        (mem_resp_ready && mem_resp_valid) |-> (current_state == M_WAIT_RESP))
        else $error("mem response accepted outside M_WAIT_RESP");

endmodule

// ---- Bind the checker into the DUT ----
// This attaches cache_assertions to every instance of direct_mapped_cache,
// wiring the checker's ports to the DUT's internal signals by name.
bind direct_mapped_cache cache_assertions u_cache_assertions (
    .clk(clk),
    .rst(rst),
    .cpu_req_valid(cpu_req_valid),
    .cpu_req_ready(cpu_req_ready),
    .cpu_resp_valid(cpu_resp_valid),
    .cpu_resp_ready(cpu_resp_ready),
    .cpu_resp_data(cpu_resp_data),
    .mem_req_valid(mem_req_valid),
    .mem_req_ready(mem_req_ready),
    .mem_addr(mem_addr),
    .mem_resp_valid(mem_resp_valid),
    .mem_resp_ready(mem_resp_ready),
    .current_state(dut.current_state)
);