`timescale 1ns / 1ps

module nn_layer #(
    parameter NUM_INPUTS = 784,
    parameter NUM_NEURONS = 128,
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_FILE = "layer_1_weights.mif",
    parameter BIAS_FILE = "layer_1_biases.mif"
)(
    input clk,
    input rst,
    input [DATA_WIDTH-1:0] data_in,
    input input_valid,
    input [31:0] local_addr,
    output [NUM_NEURONS-1:0] out_valids,
    output [NUM_NEURONS*DATA_WIDTH-1:0] layer_out
);

    genvar i;
    generate
        for (i = 0; i < NUM_NEURONS; i = i + 1) begin : neuron_block
            wire [DATA_WIDTH-1:0] w_wire;
            wire [DATA_WIDTH-1:0] b_wire;
            wire [DATA_WIDTH-1:0] n_out;

            // 1. Instance Weight Memory for this specific neuron
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

            // 2. Instance Bias Memory for this specific neuron
            Bias_Memory #(
                .NEURON_ID(i),           // Now this matches the parameter in bm
                .NUM_NEURONS(NUM_NEURONS),
                .BIAS_FILE(BIAS_FILE)
            ) bm (
                .clk(clk),
                .bias_out(b_wire)        // NEURON_ID port removed from here
            );

            // 3. Instance the Neuron itself
            neuron #(
                .IN_WIDTH(DATA_WIDTH),
                .OUT_WIDTH(DATA_WIDTH),
                .NUM_INPUTS(NUM_INPUTS)
            ) n_inst (
                .clk(clk),
                .rst(rst),
                .data_in(data_in),
                .weight_in(w_wire),
                .bias_in(b_wire),
                .input_valid(input_valid),
                .data_out(n_out),
                .out_valid(out_valids[i])
            );

            // 4. Pack the 16-bit output into the wide layer bus
            assign layer_out[i*DATA_WIDTH +: DATA_WIDTH] = n_out;
        end
    endgenerate

endmodule