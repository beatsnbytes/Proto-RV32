

module direct_mapped_cache_tb;

    logic clk; 
    logic rst;
    // CPU-side
    logic cpu_req_write;
    logic cpu_req_valid; 
    logic cpu_req_ready;
    logic [31 : 0] cpu_addr;
    logic [31 : 0] cpu_wdata;
    logic [31 : 0] cpu_resp_data;
    logic cpu_resp_valid;
    logic cpu_resp_ready;
    // Main memory side
    logic mem_req_write;
    logic mem_req_valid;
    logic mem_req_ready;
    logic [31 : 0] mem_addr;
    logic [31 : 0] mem_wdata;
    logic mem_resp_valid;
    logic mem_resp_ready;
    logic [127 : 0] mem_resp_data;

    logic [31:0] base;

    localparam int MEM_LINES = 1024; // Addresses ranging from 0x0000_0000 to 0x0000_3FFF 1KB
    localparam int MEM_DEPTH = $clog2(MEM_LINES) + 4; // Adding the last 4 bits which are dedicated to offset
    localparam int MEM_WORDS = MEM_LINES * 4;
    localparam int SHADOW_MEM_DEPTH = $clog2(MEM_WORDS) + 2;
    logic [127 : 0] backing_mem [MEM_LINES-1 : 0]; // What the cache-side has
    logic [31:0] shadow_mem [MEM_WORDS-1 : 0]; 
    logic [31:0] addr;

    direct_mapped_cache dut(
        .clk(clk), 
        .rst(rst),
        // CPU-side
        .cpu_req_write(cpu_req_write),
        .cpu_req_valid(cpu_req_valid), 
        .cpu_req_ready(cpu_req_ready),
        .cpu_addr(cpu_addr),
        .cpu_wdata(cpu_wdata),
        .cpu_resp_data(cpu_resp_data),
        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_ready(cpu_resp_ready),
        // Main memory side
        .mem_req_write(mem_req_write),
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_ready(mem_resp_ready),
        .mem_resp_data(mem_resp_data)
    );

    int errors = 0;
    int mem_req_read_cnt = 0;
    int mem_req_write_cnt = 0;
    int mem_req_read_current = 0;
    int mem_req_write_current = 0;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // // Global tiemout block
    // initial begin
    //     #10000;
    //     $display("TIMEOUT — errors=%0d", errors);
    //     $finish;
    // end

    // Initialize the backing memory
    initial begin
        for(int i=0; i<=MEM_LINES-1; i++) begin
            backing_mem[i][0 +: 32] = i*16 + 32'd0;
            backing_mem[i][1*32 +: 32] = i*16 + 32'd4;
            backing_mem[i][2*32 +: 32] = i*16 + 32'd8;
            backing_mem[i][3*32 +: 32] = i*16 + 32'd12;
        end
    end

    // Initialize the shadow memory
    initial begin
        for(int i=0; i<=MEM_LINES-1; i++) begin
            shadow_mem[i*4 + 0] = i*16 + 32'd0;
            shadow_mem[i*4 + 1] = i*16 + 32'd4;
            shadow_mem[i*4 + 2] = i*16 + 32'd8;
            shadow_mem[i*4 + 3] = i*16 + 32'd12;
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
                    backing_mem[mem_addr[(MEM_DEPTH-1):4]][mem_addr[3:2]*32 +: 32] = mem_wdata; 

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

    task automatic cpu_write(input [31:0] addr, input [31:0] wdata);
        cpu_addr = addr;
        cpu_wdata = wdata;
        cpu_req_write = 1'b1;
        cpu_req_valid = 1'b1;
        cpu_resp_ready = 1'b1;
        // #1;
        do
        @(posedge clk);
        while (!cpu_req_ready);
        #1;
        cpu_req_valid = 1'b0;

        do
        @(posedge clk);
        while (!cpu_resp_valid);
        #1;
        cpu_resp_ready = 1'b0;

        shadow_mem[addr[(SHADOW_MEM_DEPTH -1):2]] = wdata;

    endtask

    task automatic cpu_req (input [31:0] addr);

        cpu_addr = addr;
        cpu_req_valid = 1'b1;
        cpu_resp_ready = 1'b1;
        cpu_req_write = 1'b0;


        // $display("CPU: req_valid asserted, waiting cache to assert req_ready");

        do begin
            @(posedge clk);    
        end while (!cpu_req_ready);
        #1;
        cpu_req_valid = 1'b0;
        

        // $display("CPU: Waiting cache to assert resp_valid");
        do begin
        @(posedge clk); 
        end while(!cpu_resp_valid);

        assert(cpu_resp_data === (shadow_mem[addr[(SHADOW_MEM_DEPTH -1):2]]))
        else begin
            $display("ERROR: Expected %h, but got %h", (shadow_mem[addr[(SHADOW_MEM_DEPTH -1):2]]), cpu_resp_data);
            errors = errors + 1;
        end 

        #1;
        cpu_resp_ready = 1'b0;



    endtask



    task automatic cpu_req_slow (input [31:0] addr);

        cpu_addr = addr;
        cpu_req_valid = 1'b1;
        cpu_resp_ready = 1'b0;


        // $display("CPU: req_valid asserted, waiting cache to assert req_ready");

        do begin
            @(posedge clk);    
        end while (!cpu_req_ready);
        #1;
        cpu_req_valid = 1'b0;
        

        // $display("CPU: Waiting cache to assert resp_valid");
        wait(cpu_resp_valid === 1'b1);


        repeat (20) begin
            @(posedge clk);
            assert (cpu_resp_valid === 1'b1) else begin
                $display("ERROR: cache dropped resp_valid before accept!"); errors++;
            end
            assert (cpu_resp_data === (addr & ~32'd3)) else begin
                $display("ERROR: cache changed resp_data before accept!"); errors++;
            end
        end

        #1;
        cpu_resp_ready = 1'b1;

        while(!cpu_resp_valid) begin
            @(posedge clk);    
        end
        
        assert(cpu_resp_data === (addr & ~32'd3))
        else begin
            $display("ERROR: Expected %h, but got %h", (addr & ~32'd3), cpu_resp_data);
            errors = errors + 1;
        end 

        
        @(posedge clk); #1;
        cpu_resp_ready = 1'b0;

    endtask


    initial begin
        $dumpfile("../sim/direct_mapped_cache_tb.vcd");
        $dumpvars(0, direct_mapped_cache_tb);

        rst = 1'b1;
        repeat(3) @(posedge clk); #1;
        rst = 1'b0;
        repeat(3) @(posedge clk); #1;



        // // Cold miss on addr 0x0000_A000
        // $display("TEST 1 : Cold miss on addr 0x0000_A0000");
        // cpu_req(32'h0000_A000);
        // repeat(5) @(posedge clk); #1;
        // if(errors == 0) $display("PASS");


        // mem_req_current = mem_req_cnt;
        // // Hit after miss
        // $display("TEST 2 : Hit after miss on addr 0x0000_A0000");
        // cpu_req(32'h0000_A000);
        // repeat(5) @(posedge clk); #1;
        // assert (mem_req_current === mem_req_cnt) $display("PASS!"); else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end


        // $display("TEST 3 : Hit within the same line. Spatial locality");
        // cpu_req(32'h0000_A000);
        // repeat(5) @(posedge clk); #1;
        // assert (mem_req_current == mem_req_cnt) begin
        //     assert (errors == 0) begin 
        //         $display("PASS (3a)");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end

        // cpu_req(32'h0000_A004);
        // repeat(5) @(posedge clk); #1;
        // assert (mem_req_current == mem_req_cnt) begin
        //     assert (errors == 0) begin 
        //         $display("PASS (3b)");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end

        // cpu_req(32'h0000_A008);
        // repeat(5) @(posedge clk); #1;
        // assert (mem_req_current == mem_req_cnt) begin
        //     assert (errors == 0) begin 
        //         $display("PASS (3c)");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end

        // cpu_req(32'h0000_A00B);
        // repeat(5) @(posedge clk); #1;
        // assert (mem_req_current == mem_req_cnt) begin
        //     assert (errors == 0) begin 
        //         $display("PASS (3d)");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end

        // $display("TEST 4 : Conflict & Eviction check");
        // cpu_req(32'h0100_A000);
        // repeat(5) @(posedge clk); #1;        
        // assert (mem_req_cnt == (mem_req_current + 1)) begin
        //     assert (errors == 0) begin 
        //         $display("PASS (4a)");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end


        // mem_req_current = mem_req_cnt;
        // cpu_req(32'h0000_A000);
        // repeat(5) @(posedge clk); #1;        
        // assert (mem_req_cnt == mem_req_current + 1) begin
        //     assert (errors == 0) begin 
        //         $display("PASS (4b)");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end
        

        // mem_req_current = mem_req_cnt;
        // $display("TEST 5 : Backpressure");
        // cpu_req_slow(32'h0000_C000);
        // repeat(5) @(posedge clk); #1; 
        // assert (mem_req_cnt == mem_req_current + 1) begin
        //     assert (errors == 0) begin 
        //         $display("PASS");
        //     end 
        // end else begin
        //     $display("ERROR: Sent memory request while data in cache!");
        //     errors = errors + 1;    
        // end

    // STORE TEST

        // Scenario 1 — Write hit (write through)
        $display("Scenario 1 — Write hit (write through)");
        cpu_req(32'h0000_0A00);
        repeat(5) @(posedge clk); #1;

        cpu_write(32'h0000_0A00, 32'hDEAD_BEEF);
        repeat(5) @(posedge clk); #1;

        cpu_req(32'h0000_0A00);
        repeat(5) @(posedge clk); #1;

        // Scenario 2 — Write miss (write-allocate)

        $display("Scenario 2 — Write miss (write-allocate)");
        mem_req_write_current = mem_req_write_cnt;
        mem_req_read_current = mem_req_read_cnt;
        cpu_write(32'h0000_0F00, 32'hCAFE_BABE);
        repeat(5) @(posedge clk); #1;
        assert((mem_req_write_cnt === (mem_req_write_current + 1)) && (mem_req_read_cnt === (mem_req_read_current + 1))) begin
            assert(errors === 0) begin
                $display("PASS");
            end
        end 

        mem_req_read_current = mem_req_read_cnt;
        cpu_req(32'h0000_0F0C);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_read_cnt === (mem_req_read_current)) begin
            assert (errors === 0) begin 
                $display("PASS");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end

        // Scenario 3 — Write-through actually reaches memory
        $display("Scenario 3 — Write-through actually reaches memory");
        addr = 32'h0000_0C00;
        cpu_write(addr, 32'hCAFE_FFFF);
        repeat(5) @(posedge clk); #1;
        assert(backing_mem[addr[(MEM_DEPTH-1):4]][addr[3:2]*32 +: 32] == 32'hCAFE_FFFF) else begin
            $display("ERROR: Write through didnt reach the main memory");
        end

        // Scenario 4 — Store then evict, then re-read (the coherence proof)
        $display("Scenario 4 — Store then evict, then re-read (the coherence proof)");
        cpu_write(32'h0000_0100, 32'hBABE_BABE);
        repeat(5) @(posedge clk); #1;

        mem_req_read_current = mem_req_read_cnt;
        cpu_req(32'h0000_0500); // Conflicting address, evicts the previous
        repeat(5) @(posedge clk); #1;
        assert (mem_req_read_cnt === (mem_req_read_current + 1)) else begin
            $display("ERROR: Didnt miss again to fetch the evicted address!");
        end

        mem_req_read_current = mem_req_read_cnt;
        cpu_req(32'h0000_0100);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_read_cnt === (mem_req_read_current + 1)) else begin
            $display("ERROR: Didnt miss again to fetch the evicted address!");
        end


        




        if(errors == 0) $display("TESTNG COMPLETE. SUCCESS!");
        $display("Errors : %d", errors);
        $finish;
    end


endmodule
