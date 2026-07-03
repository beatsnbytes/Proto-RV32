// async_fifo_tb.sv
// Testbench for the asynchronous FIFO
// Reset — assert and deassert, verify empty=1, full=0
// Write known sequence — fill the FIFO completely
// Write while full — verify no data corruption, full stays asserted
// Read all data — verify data integrity, correct order
// Read while empty — verify no corruption, empty stays asserted
// Simultaneous read and write — write side keeps writing, read side keeps reading at different clock rates, verify data integrity throughout
// Irrational ratio between clocks


module async_fifo_tb;

    localparam int DEPTH = 8;
    localparam int DATA_WIDTH = 4;
    logic clk_wr;
    logic wr_en;
    logic clk_rd;
    logic rd_en;
    logic arst;  
    logic [DATA_WIDTH-1 : 0] data_in;
    logic [DATA_WIDTH-1 : 0] data_out;
    logic full;
    logic empty;

    logic [31:0] input_sequence;
    logic [31:0] output_sequence;
    int idx;
    logic [DATA_WIDTH-1 : 0] last_valid_read;

    logic [DATA_WIDTH-1 : 0] ref_queue[$];
    logic [DATA_WIDTH-1 : 0] wr_data, rd_data;

    int wr_count, rd_count;

    async_fifo #(
        .DEPTH(DEPTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk_wr(clk_wr),
        .wr_en(wr_en),
        .clk_rd(clk_rd),
        .rd_en(rd_en),
        .arst(arst),  
        .data_in(data_in),
        .data_out(data_out),
        .full(full),
        .empty(empty)
    );


    initial clk_wr = 1'b0;
    always #10 clk_wr = ~clk_wr;

    initial clk_rd = 1'b0;
    always #7 clk_rd = ~clk_rd;

    initial begin
    $dumpfile("../sim/async_fifo_tb.vcd");
    $dumpvars(0, async_fifo_tb);

    // Initialize the wr and rd enable signals to 0
    wr_en = 1'b0;
    rd_en = 1'b0;

    arst = 1'b0;
    #40; // Wait 40 time units to assert it. Since its asynchrnonous we do not tie it to any clocks period
    arst = 1'b1;

    // After reset the fifo should be empty and not full
    assert (!full) else $error("FIFO should not be full");
    assert (empty)  else $error("FIFO should be empty after reset");

    // Write known sequence — fill the FIFO completely
    input_sequence = 32'hDEADBEEF;
    @(posedge clk_wr); #1;
    wr_en = 1'b1;
    idx = 0;

    repeat(8) begin 
        data_in = input_sequence[idx*4 +: 4]; 
        @(posedge clk_wr); #1;
        idx = idx + 1;
    end

    // Write while full — verify no data corruption, full stays asserted
    assert (full) else $error("FIFO should be full");
    @(posedge clk_wr); #1;
    data_in  = 4'h0;
    @(posedge clk_wr); #1;
    assert (full) else $error("FIFO should be full");
    wr_en = 1'b0;
    @(posedge clk_wr); #1;

    // Read all data — verify data integrity, correct order
    rd_en = 1'b1;
    idx = 0;

    repeat(8) begin
        output_sequence[idx*4 +: 4] = data_out;
        assert(data_out == input_sequence[idx*4 +: 4]) else $error("Data mismatch at index %0d. Expected %h, got %h", idx, input_sequence[idx*4 +: 4], data_out);
        @(posedge clk_rd); #1;
        idx = idx + 1;
    end

    last_valid_read = data_out;

    assert (empty)  else $error("FIFO should be empty after reading all the values");
    @(posedge clk_rd); #1;
    // Read while empty — verify no corruption, empty stays asserted
    assert(data_out == last_valid_read) else $error("FIFO should be giving last valid read since its empty");
    rd_en = 1'b0;
    @(posedge clk_rd); #1;

    // Simultaneous read and write — write side keeps writing, read side keeps reading at different clock rates, verify data integrity throughout
    wr_en = 1'b1;
    rd_en = 1'b1;




    wr_count = 0;
    rd_count = 0;

    fork
        // Write thread. Driven by clk_wr
        begin
            repeat(16) begin
                @(posedge clk_wr); #1;
                if (!full) begin
                    wr_data = (DATA_WIDTH)'($urandom_range(0, 15));
                    data_in = wr_data;
                    wr_en = 1'b1;
                    ref_queue.push_back(wr_data);
                    wr_count++;
                end else begin
                    wr_en = 1'b0;
                end
            end
            wr_en = 1'b0;
        end
        // Read thread — driven by clk_rd
        begin
            repeat(16) begin
                @(posedge clk_rd); #1;
                if (!empty) begin
                    rd_en = 1'b1;
                    @(posedge clk_rd); #1;
                    rd_data = data_out;
                    assert(rd_data == ref_queue.pop_front()) 
                        else $error("Simultaneous test: data mismatch");
                    rd_count++;
                end else begin
                    rd_en = 1'b0;
                end
            end
            rd_en = 1'b0;
        end
    join

    $finish;
    end


endmodule