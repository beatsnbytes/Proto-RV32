// riscv_soc.sv
// The top level module that connects riscv_cpu, the cache and the main memory model

//TODO change the assertions module hierarchies

module riscv_soc #(
    parameter string IMEM_HEX_FILE = "UNSET.hex", // Deliberately unset so if the forwarding parameter chain is broken, it produces a loud failure instead of a silent error,
    parameter string DMEM_HEX_FILE = "UNSET.hex"
)(
    input logic clk,
    input logic rst
    );

    riscv_cpu #(
        .IMEM_HEX_FILE(IMEM_HEX_FILE)
    )riscv_cpu_inst(
        .clk(clk),
        .rst(rst),
        //CPU-to-Cache interface
        .cpu_req_write(cpu_req_write), // Read = 0, Write = 1
        .cpu_req_valid(cpu_req_valid), 
        .cpu_req_ready(cpu_req_ready),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_wmask(cpu_wmask),
        .cpu_resp_data(cpu_resp_data),
        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_ready(cpu_resp_ready)        
    );

    // Cache-to-CPU connection
    logic cpu_req_write;
    logic cpu_req_valid;
    logic cpu_req_ready;
    logic [31:0] cpu_addr;
    logic [31:0] cpu_wdata;
    logic [3:0] cpu_wmask;
    logic cpu_resp_ready;
    logic cpu_resp_valid;
    logic [31:0] cpu_resp_data;
    
    // Cache-to-main_memory connection
    logic mem_req_write;
    logic mem_req_valid;
    logic mem_req_ready;
    logic [31:0] mem_addr;
    logic [127:0] mem_wdata;
    logic mem_resp_ready;
    logic mem_resp_valid;
    logic [127:0] mem_resp_data;


    direct_mapped_cache direct_mapped_cache_inst(  // 1KB = 64 entries -- 128 bits wide each -- 4 * 32bit words
        .clk(clk),
        .rst(rst),
        // CPU-side
        .cpu_req_write(cpu_req_write), // Read = 0, Write = 1
        .cpu_req_valid(cpu_req_valid), 
        .cpu_req_ready(cpu_req_ready),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_wmask(cpu_wmask),
        .cpu_resp_data(cpu_resp_data),
        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_ready(cpu_resp_ready),   
        // Main memory side
        .mem_req_write(mem_req_write),  // Read = 0, Write = 1
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),          //128 bits deep
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_ready(mem_resp_ready),
        .mem_resp_data(mem_resp_data)   //128 bits deep
    );

    main_memory #(
        .DMEM_HEX_FILE(DMEM_HEX_FILE)
    )main_memory_inst( // 16KB main memory model -- 1024 entries --128 bits wide each -- 4 * 32bit words
        .clk(clk),
        .rst(rst),
        .mem_req_write(mem_req_write),  // Read = 0, Write = 1
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),          //128 bits deep
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_ready(mem_resp_ready),
        .mem_resp_data(mem_resp_data)   //128 bits deep
    );



endmodule