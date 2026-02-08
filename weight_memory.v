`timescale 1ns / 1ps

module Weight_Memory #(
    parameter NEURON_ID = 0,
    parameter NUM_NEURONS = 128,
    parameter NUM_WEIGHTS = 784,
    parameter WEIGHT_FILE = "layer_1_weights.mif"
)(
    input clk,
    input [31:0] local_addr,
    output reg [3:0] weight_out // Updated to 4-bit
);

    reg [3:0] mem [0:NUM_WEIGHTS-1];

    initial begin
        // Loads the Int4 weights from the updated moodel.py export
        $readmemb(WEIGHT_FILE, mem);
    end

    always @(posedge clk) begin
        weight_out <= mem[local_addr];
    end
endmodule