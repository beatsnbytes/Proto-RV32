// async_fifo.sv
// Asynchronous FIFO implementation

module async_fifo #(
    parameter DEPTH = 8,
    parameter DATA_WIDTH = 32
    )(
    input logic clk_wr,
    input logic wr_en,
    input logic clk_rd,
    input logic rd_en,
    input logic arst,                       // Active low asynchronous reset
    input logic [DATA_WIDTH-1 : 0] data_in,
    output logic [DATA_WIDTH-1 : 0] data_out,
    output logic full,
    output logic empty
    );

    localparam int PTR_WIDTH = $clog2(DEPTH);
    logic [DATA_WIDTH-1 : 0] fifo_mem [DEPTH-1 : 0];
    // Binary pointers (local to each domain)
    logic [PTR_WIDTH:0] wr_ptr_bin;  // one extra bit for full/empty detection
    logic [PTR_WIDTH:0] rd_ptr_bin;

    // Gray coded pointers
    logic [PTR_WIDTH:0] wr_ptr_gray;
    logic [PTR_WIDTH:0] rd_ptr_gray;

    // Synchronized Gray pointers (crossing domains)
    logic [PTR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2; // synced to rd_clk
    logic [PTR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2; // synced to wr_clk

    // Write logic
    always_ff @(posedge clk_wr) begin
        if (!rst_wr_n) begin
            wr_ptr_bin <= '0;
        end else begin
            if (wr_en && !full) begin
                fifo_mem[wr_ptr_bin[(PTR_WIDTH)-1 : 0]] <= data_in; // Index the fifo memory without the extra MSB bit
                wr_ptr_bin <= wr_ptr_bin + (PTR_WIDTH+1)'(1);
            end
        end
    end

    // Read logic
    always_ff @(posedge clk_rd) begin
        if (!rst_rd_n) begin
            rd_ptr_bin <= '0;
        end else begin
            if (rd_en && !empty) begin
                data_out <= fifo_mem[rd_ptr_bin[(PTR_WIDTH)-1 : 0]]; // Index the fifo memory without the extra MSB bit 
                rd_ptr_bin <= rd_ptr_bin + (PTR_WIDTH+1)'(1);
            end
        end
    end

    // Binary to Gray-code conversion (Write)
    assign wr_ptr_gray = {wr_ptr_bin[PTR_WIDTH], (wr_ptr_bin[PTR_WIDTH:1]^wr_ptr_bin[PTR_WIDTH-1:0])};

    // Binary to Gray-code conversion (Read)
    assign rd_ptr_gray = {rd_ptr_bin[PTR_WIDTH], (rd_ptr_bin[PTR_WIDTH:1]^rd_ptr_bin[PTR_WIDTH-1:0])};

    // Assign the empty and full flags using the respective pointers
    assign empty = (rd_ptr_gray == wr_ptr_gray_sync2) ? 1'b1 : 1'b0;
    assign full = (wr_ptr_gray == {~rd_ptr_gray_sync2[PTR_WIDTH], rd_ptr_gray_sync2[PTR_WIDTH-1:0]}); 

    // Gray pointer (write) synchronizer
    always_ff @(posedge clk_wr) begin
        if (!rst_wr_n) begin
            rd_ptr_gray_sync1 <= '0;
            rd_ptr_gray_sync2 <= '0;                    
        end else begin
            rd_ptr_gray_sync1 <= rd_ptr_gray;
            rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
        end
    end

    // Gray pointer (write) synchronizer
    always_ff @(posedge clk_rd) begin
        if (!rst_rd_n) begin
            wr_ptr_gray_sync1 <= '0;
            wr_ptr_gray_sync2 <= '0;                    
        end else begin
            wr_ptr_gray_sync1 <= wr_ptr_gray;
            wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
        end
    end



    // Write domain reset synchronizer
    logic rst_wr_sync1, rst_wr_n;
    always_ff @(posedge clk_wr or negedge arst) begin
        if (!arst) begin
            rst_wr_sync1 <= 1'b0;           // Asynchronous assertion and synchronous deassertion
            rst_wr_n     <= 1'b0;
        end else begin
            rst_wr_sync1 <= 1'b1;           // FF synchronizers
            rst_wr_n     <= rst_wr_sync1;
        end
    end

    // Read domain reset synchronizer  
    logic rst_rd_sync1, rst_rd_n;
    always_ff @(posedge clk_rd or negedge arst) begin
        if (!arst) begin
            rst_rd_sync1 <= 1'b0;
            rst_rd_n     <= 1'b0;
        end else begin
            rst_rd_sync1 <= 1'b1;
            rst_rd_n     <= rst_rd_sync1;
        end
    end

endmodule