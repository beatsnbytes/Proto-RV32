// riscv_fetch.sv
// Fetch stage module for the RISC-V processor pipeline


module riscv_fetch #(
    parameter string IMEM_HEX_FILE = "UNSET.hex" // Deliberately unset so if the forwarding parameter chain is broken, it produces a loud failure instead of a silent error    
)(
    input logic [31:0] pc,
    output logic [31:0] instr
);


    logic [31:0] imem [16383:0]; // The 64KB memory

    `ifdef FORMAL // TODO implement functionality for formal verification. This is never excercised now
        // imem left unconstrained for formal verification
    `else
       initial $readmemh(IMEM_HEX_FILE, imem); // Reading the instructions from a hex file
        // initial $readmemh("/home/vatistas/hdl_rampup/sv-learning/rtl/test_words.hex", imem); // Reading the instructions from a hex file
    `endif

    assign instr = imem[pc[15:2]]; // Word addressed imem and 32bit instructions. Not counting the 2 LSBs


endmodule