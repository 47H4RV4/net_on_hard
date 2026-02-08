`timescale 1ns / 1ps

module image_rom (
    input clk,
    input [9:0] addr,
    output reg [3:0] q // 4-bit Int4 data
);

    reg [3:0] rom [0:783];

    initial begin
        // Loads the 4-bit MIF prepared by updated model.py
        $readmemb("mnist_sample.mif", rom);
    end

    always @(posedge clk) begin
        q <= rom[addr];
    end

endmodule