// mul_formal.sv
// Formal verification for the mul module done <> busy

module mul_formal;
    bind riscv_mul mul_formal_props props_inst (
        .clk(clk),
        .rst(rst),
        .done(done),
        .busy(busy)
    );
endmodule

module mul_formal_props (
    input logic clk,
    input logic rst,
    input logic done,
    input logic busy
);

always @(posedge clk) begin
    if (!rst)
        assert (!(done && busy));
end

endmodule