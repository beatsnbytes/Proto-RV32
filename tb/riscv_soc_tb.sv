// riscv_soc_tb.sv
// Test all the modules of the SoC connected together
// Week10 - Testing th whole SoC

//TODO change tb accoringly. drive simulation signals to the riscv_soc instead. how to deal with main memory model?
module riscv_soc_tb;

    logic clk, rst;
    logic [31:0] pc, exec_result;
    logic zero;

    riscv_soc dut (
    .clk(clk),
    .rst(rst)
    );

    initial clk = 1'b0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("../sim/riscv_soc_tb.vcd");
        $dumpvars(0, riscv_soc_tb);

        // Reset for 2 cycles
        rst = 1'b1;
        repeat(2) @(posedge clk); #1;
        rst = 1'b0;

        // Wait enough cycles to see the output of the alu
        repeat(1000) @(posedge clk); #1;

        $finish;
    end

    // initial begin
        // $monitor("time=%2t pc=%h | exec_result=%h | zero=%b",
        // $time, pc, exec_result, zero);
    // end

endmodule