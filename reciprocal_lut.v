`timescale 1ns / 1ps

module reciprocal_lut (
    input clk,
    input [9:0] addr,
    output reg [15:0] q // Make sure this is named 'q'
);
    reg [15:0] mem [0:1023];

    initial begin
        $readmemb("reciprocal_table.mif", mem);
    end

    always @(posedge clk) begin
        q <= mem[addr];
    end
endmodule