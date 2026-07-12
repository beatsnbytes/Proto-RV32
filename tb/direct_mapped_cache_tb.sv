

module direct_mapped_cache_tb;

    logic clk; 
    logic rst;
    // CPU-side
    logic cpu_req_valid; 
    logic cpu_req_ready;
    logic [31 : 0] cpu_addr;
    logic [31 : 0] cpu_resp_data;
    logic cpu_resp_valid;
    logic cpu_resp_ready;
    // Main memory side
    logic mem_req_valid;
    logic mem_req_ready;
    logic [31 : 0] mem_addr;
    logic mem_resp_valid;
    logic mem_resp_ready;
    logic [127 : 0] mem_resp_data;

    logic [31:0] base;

    direct_mapped_cache dut(
        .clk(clk), 
        .rst(rst),
        // CPU-side
        .cpu_req_valid(cpu_req_valid), 
        .cpu_req_ready(cpu_req_ready),
        .cpu_addr(cpu_addr),
        .cpu_resp_data(cpu_resp_data),
        .cpu_resp_valid(cpu_resp_valid),
        .cpu_resp_ready(cpu_resp_ready),
        // Main memory side
        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_addr(mem_addr),
        .mem_resp_valid(mem_resp_valid),
        .mem_resp_ready(mem_resp_ready),
        .mem_resp_data(mem_resp_data)
    );

    int errors = 0;
    int mem_req_cnt = 0;
    int mem_req_current = 0;

    initial clk = 1'b0;
    always #5 clk = ~clk;

    // // Global tiemout block
    // initial begin
    //     #10000;
    //     $display("TIMEOUT — errors=%0d", errors);
    //     $finish;
    // end

    // Golden model for main memory behavior
    initial begin
        mem_req_ready = 1'b1; // alwaysready to accept
        mem_resp_valid  = 1'b0;
        mem_resp_data = '0;

        forever begin
            @(posedge clk);

            if (mem_req_ready && mem_req_valid) begin
                mem_req_cnt = mem_req_cnt + 1;
                base = mem_addr;
                repeat(5) @(posedge clk); #1;
                mem_resp_data = {base+32'd12, base+32'd8, base+32'd4, base+32'd0};
                mem_resp_valid = 1'b1;
                do begin
                @(posedge clk);
                end while(!mem_resp_ready);
                #1;
                mem_resp_valid = 1'b0;
            end
        end
    end

    task automatic cpu_req (input [31:0] addr);

        cpu_addr = addr;
        cpu_req_valid = 1'b1;
        cpu_resp_ready = 1'b1;


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

        assert(cpu_resp_data === (addr & ~32'd3))
        else begin
            $display("ERROR: Expected %h, but got %h", (addr & ~32'd3), cpu_resp_data);
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


        // Cold miss on addr 0x0000_A000
        $display("TEST 1 : Cold miss on addr 0x0000_A0000");
        cpu_req(32'h0000_A000);
        repeat(5) @(posedge clk); #1;
        if(errors == 0) $display("PASS!");


        mem_req_current = mem_req_cnt;
        // Hit after miss
        $display("TEST 2 : Hit after miss on addr 0x0000_A0000");
        cpu_req(32'h0000_A000);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_current === mem_req_cnt) $display("PASS!"); else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end


        $display("TEST 3 : Hit within the same line. Spatial locality");
        cpu_req(32'h0000_A000);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_current == mem_req_cnt) begin
            assert (errors == 0) begin 
                $display("PASS! (3a)");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end

        cpu_req(32'h0000_A004);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_current == mem_req_cnt) begin
            assert (errors == 0) begin 
                $display("PASS! (3b)");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end

        cpu_req(32'h0000_A008);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_current == mem_req_cnt) begin
            assert (errors == 0) begin 
                $display("PASS! (3c)");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end

        cpu_req(32'h0000_A00B);
        repeat(5) @(posedge clk); #1;
        assert (mem_req_current == mem_req_cnt) begin
            assert (errors == 0) begin 
                $display("PASS! (3d)");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end

        $display("TEST 4 : Conflict & Eviction check");
        cpu_req(32'h0100_A000);
        repeat(5) @(posedge clk); #1;        
        assert (mem_req_cnt == (mem_req_current + 1)) begin
            assert (errors == 0) begin 
                $display("PASS! (4a)");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end


        mem_req_current = mem_req_cnt;
        cpu_req(32'h0000_A000);
        repeat(5) @(posedge clk); #1;        
        assert (mem_req_cnt == mem_req_current + 1) begin
            assert (errors == 0) begin 
                $display("PASS! (4b)");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end
        

        mem_req_current = mem_req_cnt;
        $display("TEST 5 : Backpressure");
        cpu_req_slow(32'h0000_C000);
        repeat(5) @(posedge clk); #1; 
        assert (mem_req_cnt == mem_req_current + 1) begin
            assert (errors == 0) begin 
                $display("PASS!");
            end 
        end else begin
            $display("ERROR: Sent memory request while data in cache!");
            errors = errors + 1;    
        end



        $display("Errors : %d", errors);
        $finish;
    end


endmodule
