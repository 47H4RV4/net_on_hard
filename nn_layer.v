`timescale 1ns / 1ps

module nn_layer #(
    parameter NUM_INPUTS = 784,
    parameter NUM_NEURONS = 128,
    parameter DATA_WIDTH = 16,
    parameter SHIFT = 8,
    parameter USE_RELU = 1, // Parameter for freedom to bypass
    parameter WEIGHT_FILE = "layer_1_weights.mif",
    parameter BIAS_FILE = "layer_1_biases.mif"
)(
    input clk, rst,
    input [DATA_WIDTH-1:0] data_in,
    input input_valid,
    input [31:0] local_addr,
    output [NUM_NEURONS-1:0] out_valids,
    output [NUM_NEURONS*DATA_WIDTH-1:0] layer_out
);

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_block
            wire [DATA_WIDTH-1:0] w_wire, b_wire, raw_out, activated_out;

            Weight_Memory #(.NEURON_ID(i), .NUM_NEURONS(NUM_NEURONS), .NUM_WEIGHTS(NUM_INPUTS), .WEIGHT_FILE(WEIGHT_FILE)) wm 
                (.clk(clk), .local_addr(local_addr), .weight_out(w_wire));
            Bias_Memory #(.NEURON_ID(i), .NUM_NEURONS(NUM_NEURONS), .BIAS_FILE(BIAS_FILE)) bm 
                (.clk(clk), .bias_out(b_wire));

            neuron #(.IN_WIDTH(DATA_WIDTH), .NUM_INPUTS(NUM_INPUTS), .SHIFT(SHIFT)) n_inst (
                .clk(clk), .rst(rst), .data_in(data_in), .weight_in(w_wire), .bias_in(b_wire), 
                .input_valid(input_valid), .data_out(raw_out), .out_valid(out_valids[i])
            );

            // Separate ReLU module instance
            relu #(.DATA_WIDTH(DATA_WIDTH)) r_inst (
                .data_in(raw_out), 
                .data_out(activated_out)
            );

            // Logic to choose between raw output or activated output
            assign layer_out[i*DATA_WIDTH +: DATA_WIDTH] = (USE_RELU) ? activated_out : raw_out;
            always @(posedge clk) if (out_valids[i]) 
                $display("[%0t] LAYER DEBUG: [i->%d] neuron output: %h", $time,i,layer_out[i*DATA_WIDTH +: DATA_WIDTH]);
        end
    endgenerate
endmodule