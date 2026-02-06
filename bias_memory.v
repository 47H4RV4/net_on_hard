`timescale 1ns / 1ps

module Bias_Memory #(
    parameter NEURON_ID = 0,
    parameter NUM_NEURONS = 128,
    parameter DATA_WIDTH = 16,
    parameter BIAS_FILE = "layer_1_biases.mif"
)(
    input clk,
    output reg [DATA_WIDTH-1:0] bias_out
);

    // Sized to match the number of neurons in the current layer
    reg [DATA_WIDTH-1:0] mem [0:NUM_NEURONS-1];

    initial begin
        $readmemb(BIAS_FILE, mem);
    end

    always @(posedge clk) begin
        // Returns the single bias value assigned to this specific neuron
        bias_out <= mem[NEURON_ID];
    end

endmodule