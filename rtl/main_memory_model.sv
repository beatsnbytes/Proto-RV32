    // main_memory_model.sv
    // Currently a non synthesizable model of the main memory to be able to simulate the whole SoC
    
    //TODO put ports, instantiate memories and whatever else it needs.

    module main_memory (
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
    localparam int MEM_LINES = 1024; // Addresses ranging from 0x0000_0000 to 0x0000_3FFF 1KB
    localparam int MEM_DEPTH = $clog2(MEM_LINES) + 4; // Adding the last 4 bits which are dedicated to offset
    localparam int MEM_WORDS = MEM_LINES * 4;
    localparam int SHADOW_MEM_DEPTH = $clog2(MEM_WORDS) + 2;
    logic [127 : 0] backing_mem [MEM_LINES-1 : 0]; // What the cache-side has


    int mem_req_read_cnt = 0;
    int mem_req_write_cnt = 0;


    logic [31:0] base;



        // Initialize the backing memory
    initial begin
        for(int i=0; i<=MEM_LINES-1; i++) begin
            backing_mem[i][0 +: 32] = i*16 + 32'd0;
            backing_mem[i][1*32 +: 32] = i*16 + 32'd4;
            backing_mem[i][2*32 +: 32] = i*16 + 32'd8;
            backing_mem[i][3*32 +: 32] = i*16 + 32'd12;
        end
    end



    // Golden model for main memory behavior
    initial begin
        mem_req_ready = 1'b1; // always ready to accept
        mem_resp_valid  = 1'b0;
        mem_resp_data = '0;

        forever begin
            @(posedge clk);
            if (mem_req_ready && mem_req_valid) begin
                if (mem_req_write) begin
                    mem_req_write_cnt = mem_req_write_cnt + 1;
                    // backing_mem[mem_addr[(MEM_DEPTH-1):4]][mem_addr[3:2]*32 +: 32] = mem_wdata;
                    backing_mem[mem_addr[(MEM_DEPTH-1):4]] = mem_wdata; 

                end else begin
                    mem_req_read_cnt = mem_req_read_cnt + 1;
                    base = mem_addr;
                    repeat(5) @(posedge clk); #1;
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