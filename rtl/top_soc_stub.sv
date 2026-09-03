// module riscv_soc_stub #(
//     parameter string IMEM_HEX_FILE = "UNSET.hex" // Deliberately unset so if the forwarding parameter chain is broken, it produces a loud failure instead of a silent error,  
// )(
//     input logic clk,
//     input logic rst,
//     output logic stub_output
//     );

//     // Inputs that ge value from a counter are not optimied away from the EDA tool
//     logic [31:0] seed_counter;
//     logic cpu_req_ready, cpu_resp_valid;
//     logic [31:0] cpu_resp_data;
//     always_ff @(posedge clk) seed_counter <= seed_counter + 1;

//     assign cpu_req_ready = seed_counter[0];
//     assign cpu_resp_data = seed_counter;
//     assign cpu_resp_valid = seed_counter[1];


//     // Stub output port that does not get optimized away by EDA tool
//     logic cpu_req_write, cpu_req_valid, cpu_resp_ready;
//     logic [31:0] cpu_addr, cpu_wdata ;
//     logic [3:0] cpu_wmask;
//     assign stub_output = (cpu_req_write & cpu_req_valid &  ^cpu_addr & ^cpu_wdata & ^cpu_wmask & cpu_resp_ready);


//     // The actuall DUT
//     riscv_cpu #(
//         .IMEM_HEX_FILE(IMEM_HEX_FILE)
//     )riscv_cpu_inst(
//         .clk(clk),
//         .rst(rst),
//         //CPU-to-Cache interface
//         .cpu_req_write(cpu_req_write), // Read = 0, Write = 1
//         .cpu_req_valid(cpu_req_valid), 
//         .cpu_req_ready(cpu_req_ready),
//         .cpu_addr(cpu_addr),
//         .cpu_wdata(cpu_wdata),
//         .cpu_wmask(cpu_wmask),
//         .cpu_resp_data(cpu_resp_data),
//         .cpu_resp_valid(cpu_resp_valid),
//         .cpu_resp_ready(cpu_resp_ready)        
//     );


// endmodule