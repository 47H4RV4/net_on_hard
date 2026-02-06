`timescale 1ns / 1ps

module Bias_Memory #(
    parameter NEURON_ID = 0,      // Added this as a parameter
    parameter NUM_NEURONS = 128,
    parameter DATA_WIDTH = 16,
    parameter BIAS_FILE = "layer_1_biases.mif"
)(
    input clk,
    // We can remove the NEURON_ID input port now since it's a parameter
    output reg [DATA_WIDTH-1:0] bias_out
);

    reg [DATA_WIDTH-1:0] mem [0:NUM_NEURONS-1];

    initial begin
        $readmemb(BIAS_FILE, mem);
    end

    always @(posedge clk) begin
        // Use the parameter to index the memory
        bias_out <= mem[NEURON_ID];
    end

endmodule