// cache_tb_assertions.sv — bound to the TESTBENCH, separate concern
module cache_tb_assertions #(
    parameter ADDR_WIDTH = 32,
    parameter MEM_LINES = 1024,
    parameter MEM_DEPTH = $clog2(MEM_LINES) + 4
)(
  input logic clk, rst,
  input logic trigger_cond, eviction_done_pulse,
  input logic [ADDR_WIDTH-1:0] some_addr,
  input logic [127:0] backing_mem_view [MEM_LINES-1:0]
);
  
  logic [ADDR_WIDTH-1:0] cap_addr;
  logic [127:0]       cap_old_line;
  logic                watching;

  function automatic logic [127:0] get_backing_line(input logic [ADDR_WIDTH-1:0] addr);
    return backing_mem_view[addr[MEM_DEPTH-1:4]];   // visible: bound into tb scope
  endfunction

  always_ff @(posedge clk or posedge rst) begin
    if (rst) watching <= 1'b0;
    else if (trigger_cond) begin
      cap_addr     <= some_addr;
      cap_old_line <= get_backing_line(some_addr);
      watching     <= 1'b1;
    end else if (eviction_done_pulse && watching)
      watching <= 1'b0;
  end

  property p_dirty_not_written_early;
    @(posedge clk) disable iff (rst)
    (watching && !eviction_done_pulse) |-> (get_backing_line(cap_addr) == cap_old_line);
  endproperty
  assert property (p_dirty_not_written_early);
endmodule

bind direct_mapped_cache_tb cache_tb_assertions #(
    .ADDR_WIDTH(32)
) u_cache_tb_assertions (
  .clk(clk), 
  .rst(rst),
  .trigger_cond(trigger_cond),
  .eviction_done_pulse(eviction_done_pulse),
  .some_addr(dut.cpu_addr_r),
  .backing_mem_view(backing_mem)
);