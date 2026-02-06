`timescale 1ns / 1ps

module Weight_Memory #(
    parameter NEURON_ID = 0,
    parameter NUM_NEURONS = 128,
    parameter NUM_WEIGHTS = 784,
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_FILE = "layer_1_weights.mif"
)(
    input clk,
    input [31:0] local_addr,
    output reg [DATA_WIDTH-1:0] weight_out
);

    // This ensures the memory array is exactly the right size for the specific layer
    reg [DATA_WIDTH-1:0] mem [0:(NUM_NEURONS * NUM_WEIGHTS)-1];

    initial begin
        // Loads the specific MIF file passed by the parameter
        $readmemb(WEIGHT_FILE, mem);
    end

    always @(posedge clk) begin
        // Correctly offsets into the flat file based on which neuron this memory belongs to
        weight_out <= mem[(NEURON_ID * NUM_WEIGHTS) + local_addr];
    end

endmodule