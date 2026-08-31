// riscv_soc_tb.sv
// Test all the modules of the SoC connected together
// Week10 - Testing th whole SoC

//TODO change tb accoringly. drive simulation signals to the riscv_soc instead. how to deal with main memory model?
module riscv_soc_tb;

    logic clk, rst;
    logic [31:0] pc, exec_result;
    logic zero;

    riscv_soc #(

        .IMEM_HEX_FILE("../sw/bringup/build/coremark_words.hex"),  // pass through to riscv_dfetch, assuming riscv_soc forwards this parameter down
        .DMEM_HEX_FILE("../sw/bringup/build/coremark_lines.hex")  // pass through to main_memory
        // .IMEM_HEX_FILE("../sw/bringup/build/custom_c_words.hex"),  // pass through to riscv_dfetch, assuming riscv_soc forwards this parameter down
        // .DMEM_HEX_FILE("../sw/bringup/build/custom_c_lines.hex")  // pass through to main_memory        
    )dut(
    .clk(clk),
    .rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --- Program-completion / hang detection ---
    logic [31:0] prev_pc, wb_pc_delayed;
    int repeat_count;
    logic [31:0] cycle_count;
    localparam int HALT_THRESHOLD = 3;
    // change the values below per test
    localparam int unsigned EXPECTED_RESULT = 39600;  // matches telemetry[0]
    localparam int telemetry_start = 32'h3f60;//32'h3f60; // memory line where telemetry results start. Can fit up to 4 32b results. The rest spill to the next line

    // // TRACE DUMPING
    // integer rtl_trace_file;
    // logic [31:0] wb_pc_delayed_trace;

    // initial begin
    //     rtl_trace_file = $fopen("rtl_trace.log", "w");
    // end

    // always @(posedge clk) begin
    //     wb_pc_delayed_trace <= dut.riscv_cpu_inst.wb_pc;

    //     if (dut.riscv_cpu_inst.is_retired_inst_valid) begin
    //         $fwrite(rtl_trace_file, "%h\n", wb_pc_delayed_trace);
    //     end
    // end




    always @(posedge clk) begin

        wb_pc_delayed <= dut.riscv_cpu_inst.wb_pc; // Delay the wb_pc to align with the valid retirement signal

        if (rst) begin
            prev_pc      <= 32'hFFFF_FFFF;  // force mismatch right after reset
            repeat_count <= 0;
            cycle_count <= '0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (dut.riscv_cpu_inst.is_retired_inst_valid) begin
                if (prev_pc == wb_pc_delayed) begin
                    repeat_count <= repeat_count + 1;
                end
                prev_pc <= wb_pc_delayed;
            end
            
            if (repeat_count > HALT_THRESHOLD) begin
                // Compute the line + word-within-line for each address, matching
                // the packing bin2hex.py used (word0 = lowest bits of the 128-bit line)
                automatic int telemetry_results_memory_line = telemetry_start >> 4;

                // // FOR CUSTOM CODE WITH KNOWN RESULT
                // automatic int unsigned result     = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][31:0];
                // automatic int unsigned instr     = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][63:32];
                // automatic int unsigned cycles    = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][95:64];
                // automatic real ipc = real'(instr) / real'(cycles);

                // if (result == EXPECTED_RESULT) begin
                //     $display(">>> PASS: result matches expected value (%0d)", EXPECTED_RESULT);
                // end else begin
                //     $display(">>> FAIL: result=%0d does not match expected=%0d", result, EXPECTED_RESULT);
                // end
                // $display("Total_cycles=%0d, Total_instructions=%0d, IPC=%0.4f", cycles, instr, ipc);



                // COREMARK RELATED PRINTING
                automatic int unsigned iterations    = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][31:0];
                automatic int unsigned coremark_cycles  = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][63:32];
                // automatic int unsigned total_instructions     = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][95:64];
                // automatic int unsigned total_cycles  = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][127:96];  

                automatic int unsigned crc_final     = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][95:64];
                automatic int unsigned total_errors  = dut.main_memory_inst.backing_mem[telemetry_results_memory_line][127:96];                


                $display("iterations=%0d, total_cycles=%0d, crc=0x%04h, total_errors=%0d",
                        iterations, coremark_cycles, crc_final, total_errors);

                // $display("iterations=%0d, total_cycles=%0d, instructions=%0d, cycles=%0d",                        
                //         iterations, coremark_cycles, total_instructions, total_cycles);
                // $display("IPC = %0.4f", real'(total_instructions) / real'(total_cycles));  // caution: see note below

                // $fclose(rtl_trace_file);

                $display("[%0t] Halt loop detected: PC stuck at %h", $time, wb_pc_delayed);                
                $finish;
            end
        end
    end

    // Periodical printing (COREMARK)
    always @(posedge clk) begin
        if (!rst && (cycle_count % 10_000_000 == 0)) begin
            automatic real ipc = real'(dut.riscv_cpu_inst.riscv_execute_inst.riscv_csr_inst.minstret) / real'(cycle_count);
            $display("[%0t] progress: %0d cycles, pc=%h, IPC=%0.4f",
                    $time, cycle_count, dut.riscv_cpu_inst.pc,
                    ipc);
        end
    end





    initial begin
        // $dumpfile("../sim/riscv_soc_tb.vcd");
        // $dumpvars(0, riscv_soc_tb);

        // Reset for 2 cycles
        rst = 1'b1;
        repeat(2) @(posedge clk); #1;
        rst = 1'b0;

        // Wait enough cycles to see the output of the alu
        // repeat(999999999) @(posedge clk); #1;

        // $finish;
    end

    // initial begin
        // $monitor("time=%2t pc=%h | exec_result=%h | zero=%b",
        // $time, pc, exec_result, zero);
    // end

endmodule