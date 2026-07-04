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
    logic [DATA_WIDTH-1 : 0] wr_data, rd_data, expected_data;

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
    #20; // Wait 20 time units to assert it. Since its asynchrnonous we do not tie it to any clocks period
    arst = 1'b1;
    #100; // Wait enouch time for the synchronized reset to assert in both rd and wr sides

    $display("TEST 1 : Test for empty = 1 and full = 0 on startup");
    // After reset the fifo should be empty and not full
    assert (!full) else $error("FIFO should not be full");
    assert (empty)  else $error("FIFO should be empty after reset");

    $display("TEST 2 : Send the sequence 0xDEADBEEF 4bits at a time");
    // Write known sequence — fill the FIFO completely
    input_sequence = 32'hFEEBDAED; // DEADBEEF test sequence written backwards as FIFO will read it
    @(posedge clk_wr); #2;
    wr_en = 1'b1;
    
    idx = 0;
    repeat(8) begin
        data_in = input_sequence[idx*4 +: 4];
        @(posedge clk_wr); #2;
        idx = idx + 1;          
    end



    $display("TEST 3 : Test for full = 1 after filling FIFO");
    // Write while full — verify no data corruption, full stays asserted
    assert (full) else $display("FIFO should be full");
    @(posedge clk_wr); #1;
    data_in  = 4'h0;
    @(posedge clk_wr); #1;
    assert (full) else $display("FIFO should be full");
    wr_en = 1'b0;
    @(posedge clk_rd); #2;

    $display("TEST 4 : Verify read data sequence integrity on the read side");
    // Read all data — verify data integrity, correct order
    rd_en = 1'b1;
    idx = 0;
    @(posedge clk_rd); #2; // Have to wait 1cc before I read since the read is synchronous to the rd_clk

    repeat(8) begin
        output_sequence[idx*4 +: 4] = data_out;
        assert(data_out == input_sequence[idx*4 +: 4]) else $display("Data mismatch at index %0d. Expected %h, got %h", idx, input_sequence[idx*4 +: 4], data_out);
        idx = idx + 1;
        @(posedge clk_rd); #2;
    end

    $display("TEST 5 : Test for empty = 1 after reading the whole sequence");
    last_valid_read = data_out;
    assert (empty)  else $display("FIFO should be empty after reading all the values");
    @(posedge clk_rd); #2;
    // Read while empty — verify no corruption, empty stays asserted
    $display("TEST 5 : Test for no corruption - Read on empty gives last read value");
    assert(data_out == last_valid_read) else $display("FIFO should be giving last valid read since its empty");
    rd_en = 1'b0;
    @(posedge clk_wr);
    @(posedge clk_rd);
    #2;

    // Simultaneous read and write — write side keeps writing, read side keeps reading at different clock rates, verify data integrity throughout
    // wr_en = 1'b1;
    // rd_en = 1'b1;



    $display("TEST 6 : Simultaneous write - read sequence. Test with golden model queue");
    wr_count = 0;
    rd_count = 0;
    fork
        // Write thread. Driven by clk_wr
        begin
            repeat(16) begin
                @(posedge clk_wr); #2;
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
                if (!empty) begin
                    rd_en = 1'b1;
                    @(posedge clk_rd); #2;
                    rd_data = data_out;
                    expected_data = ref_queue.pop_front();
                    assert(rd_data == expected_data) 
                        else $display("Simultaneous test: data mismatch at read %d. Expected %h, got %h", rd_count, expected_data, rd_data);
                    rd_count++;
                end else begin
                    @(posedge clk_rd); #2;
                    rd_en = 1'b0;
                end
            end
            rd_en = 1'b0;
        end
    join

    $finish;
    end


endmodule