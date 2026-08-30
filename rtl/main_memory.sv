    // main_memory.sv
    // Currently a non synthesizable model of the main memory to be able to simulate the whole SoC
    
    //TODO put ports, instantiate memories and whatever else it needs.

    module main_memory #(
        parameter string DMEM_HEX_FILE = "UNSET.hex" // Deliberately unset so if the forwarding parameter chain is broken, it produces a loud failure instead of a silent error
    )(
        input logic clk,
        input logic rst,
        input logic mem_req_write, // Read = 0, Write = 1
        input logic mem_req_valid,
        output logic mem_req_ready,
        input logic [31 : 0] mem_addr,
        input logic [127 : 0] mem_wdata,
        output logic mem_resp_valid,
        input logic mem_resp_ready,
        output logic [127 : 0] mem_resp_data
    );
    
    localparam int ADDR_WIDTH = 32;
    localparam int MEM_LINES = 4096; //64KB Addresses ranging from 0x0000_0000 to 0x0000_FFFF 64KB  - Older version: Addresses ranging from 0x0000_0000 to 0x0000_3FFF 16KB
    localparam int MEM_DEPTH = $clog2(MEM_LINES) + 4; // Adding the last 4 bits which are dedicated to offset
    localparam int MEM_WORDS = MEM_LINES * 4;
    localparam int SHADOW_MEM_DEPTH = $clog2(MEM_WORDS) + 2;
    logic [127 : 0] backing_mem [MEM_LINES-1 : 0]; // What the cache-side has
    logic [31:0] base;

    int read_latency;



    // --- Load initial memory image ---
    `ifdef FORMAL
        // backing_mem left unconstrained for formal verification
    `else
    initial $readmemh(DMEM_HEX_FILE, backing_mem);
    `endif
    
    logic [31:0] mem_addr_offset, base_offset;

    // Golden model for main memory behavior
    initial begin
        mem_req_ready = 1'b1; // always ready to accept
        mem_resp_valid  = 1'b0;
        mem_resp_data = 128'd0;



        forever begin
            @(posedge clk);
            if (mem_req_ready && mem_req_valid) begin
                if (mem_req_write) begin
                    //TODO add write response path (i.e mem_resp_valid) to the write path and make cache wait on mem_resp_valid to be symmetrically correct. Then I can add variable latency here. Currently its fire and forget.
                    // read_latency = $urandom_range(2, 10);  // pick your min/max
                    // repeat(read_latency) @(posedge clk); #1;
                    backing_mem[mem_addr[(MEM_DEPTH-1):4]] = mem_wdata; 

                end else begin
                    base = mem_addr;
                    // read_latency = $urandom_range(2, 10);  // pick your min/max
                    // repeat(read_latency) @(posedge clk); #1;
                    mem_resp_data = backing_mem[base[(MEM_DEPTH-1):4]];
                    mem_resp_valid = 1'b1;
                    do begin
                        @(posedge clk);
                    end while(!mem_resp_ready);
                    #1;
                    mem_resp_valid = 1'b0;    
                end
            end
        end
    end

endmodule