// riscv_soc_tb.sv
// Test all the modules of the SoC connected together
// Week10 - Testing th whole SoC

//TODO change tb accoringly. drive simulation signals to the riscv_soc instead. how to deal with main memory model?
module riscv_soc_tb;

    logic clk, rst;
    logic [31:0] pc, exec_result;
    logic zero;

    riscv_soc #(
        .IMEM_HEX_FILE("../sw/bringup/build/assembly_instruction_words.hex"),  // pass through to riscv_dfetch, assuming riscv_soc forwards this parameter down
        .DMEM_HEX_FILE("../sw/bringup/build/assembly_instruction_lines.hex")  // pass through to main_memory
    )dut(
    .clk(clk),
    .rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // --- Program-completion / hang detection ---
    logic [31:0] prev_pc, wb_pc_delayed;
    int repeat_count;
    localparam int HALT_THRESHOLD = 5;


    always @(posedge clk) begin

        wb_pc_delayed <= dut.riscv_cpu_inst.wb_pc; // Delay the wb_pc to align with the valid retirement signal

        if (rst) begin
            prev_pc      <= 32'hFFFF_FFFF;  // force mismatch right after reset
            repeat_count <= 0;
        end else begin
            if (dut.riscv_cpu_inst.is_retired_inst_valid) begin
                if (prev_pc == wb_pc_delayed) begin
                    repeat_count <= repeat_count + 1;
                end
                prev_pc <= wb_pc_delayed;
            end
            
            if (repeat_count > HALT_THRESHOLD) begin
                // Compute the line + word-within-line for each address, matching
                // the packing bin2hex.py used (word0 = lowest bits of the 128-bit line)
                automatic int cache_line_cycles = 32'h188 >> 4; // chooses main memory line
                automatic int cache_word_cycles = (32'h188 >> 2) & 32'h3; // chooses word in main memory line
                automatic int cache_line_instr = 32'h18c >> 4;
                automatic int cache_word_instr = (32'h18c >> 2) & 32'h3;

                automatic int unsigned cycles  = dut.main_memory_inst.backing_mem[cache_line_cycles][cache_word_cycles*32 +: 32];
                automatic int unsigned instret = dut.main_memory_inst.backing_mem[cache_line_instr][cache_word_instr*32 +: 32];

                $display("[%0t] Halt loop detected: PC stuck at %h", $time, wb_pc_delayed);
                $display("cycles = %0d, instret = %0d, IPC = %0.4f",
                        cycles, instret, real'(instret) / real'(cycles));
                $finish;
            end
        end
        // $display("[%0t] pc=%h, ra=%h, sp=%h, repeat_count=%0d",
        //   $time,
        //   dut.riscv_cpu_inst.wb_pc, 
        //   dut.riscv_cpu_inst.riscv_execute_inst.riscv_regfile_inst.regs[1], // x1=ra
        //   dut.riscv_cpu_inst.riscv_execute_inst.riscv_regfile_inst.regs[2], // x2=sp
        //   repeat_count
        //   );
    end







    initial begin
        $dumpfile("../sim/riscv_soc_tb.vcd");
        $dumpvars(0, riscv_soc_tb);

        // Reset for 2 cycles
        rst = 1'b1;
        repeat(2) @(posedge clk); #1;
        rst = 1'b0;

        // Wait enough cycles to see the output of the alu
        repeat(100000) @(posedge clk); #1;

        $finish;
    end

    // initial begin
        // $monitor("time=%2t pc=%h | exec_result=%h | zero=%b",
        // $time, pc, exec_result, zero);
    // end

endmodule