`timescale 1ns / 1ps

module image_rom #(
    parameter ADDR_WIDTH = 10, // 2^10 = 1024, enough for 784 pixels
    parameter DATA_WIDTH = 16  // Kept at 16-bit width
)(
    input clk,
    input [ADDR_WIDTH-1:0] addr,
    output reg [DATA_WIDTH-1:0] q
);

    // Memory array is 16 bits wide to accommodate the 16-bit MIF data
    reg [DATA_WIDTH-1:0] rom [0:783];

    initial begin
        // Loads the 16-bit scaled MIF file
        $readmemb("mnist_sample.mif", rom);
    end

    always @(posedge clk) begin
        q <= rom[addr];
    end
endmodule