`timescale 1ns / 1ps

module relu #(
    parameter DATA_WIDTH = 16
)(
    input [DATA_WIDTH-1:0] data_in,
    output [DATA_WIDTH-1:0] data_out
);
    // Bit 11 is the sign bit 's' in the 0000siii.ffff0000 format
    assign data_out = (data_in[11]) ? {DATA_WIDTH{1'b0}} : data_in;
endmodule