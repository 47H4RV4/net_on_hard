`timescale 1ns / 1ps

module nn_layer #(
    parameter NUM_INPUTS = 784,
    parameter NUM_NEURONS = 128,
    parameter SHIFT = 6,
    parameter WEIGHT_FILE = "layer_1_weights.mif"
)(
    input clk,
    input rst,
    input [3:0] data_in,
    input input_valid,
    input [31:0] local_addr,
    output [NUM_NEURONS-1:0] out_valids,
    output [NUM_NEURONS*4-1:0] layer_out // 4-bit activation bus
);

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_block
            wire [3:0] w_wire;

            // Int4 Weight Memory (Bias Memory removed)
            Weight_Memory #(
                .NEURON_ID(i), 
                .NUM_NEURONS(NUM_NEURONS), 
                .NUM_WEIGHTS(NUM_INPUTS), 
                .WEIGHT_FILE(WEIGHT_FILE)
            ) wm (
                .clk(clk), 
                .local_addr(local_addr), 
                .weight_out(w_wire)
            );

            // Updated Int4 Neuron instance
            neuron #(
                .IN_WIDTH(4), 
                .NUM_INPUTS(NUM_INPUTS), 
                .SHIFT(SHIFT)
            ) n_inst (
                .clk(clk), 
                .rst(rst), 
                .data_in(data_in), 
                .weight_in(w_wire), 
                .input_valid(input_valid), 
                .data_out(layer_out[i*4 +: 4]), 
                .out_valid(out_valids[i])
            );
        end
    endgenerate
endmodule