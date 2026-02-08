`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 16,
    parameter NUM_INPUTS = 784,
    parameter SHIFT = 8 
)(
    input clk, rst,
    input [IN_WIDTH-1:0] data_in,
    input [IN_WIDTH-1:0] weight_in,
    input [IN_WIDTH-1:0] bias_in,
    input input_valid,
    output reg [15:0] data_out,
    output reg out_valid
);

    reg signed [47:0] accumulator;
    reg [31:0] count;
    reg signed [47:0] final_sum;

    wire signed [15:0] s_data   = {{5{data_in[11]}}, data_in[10:0]};
    wire signed [15:0] s_weight = {{5{weight_in[11]}}, weight_in[10:0]};
    wire signed [15:0] s_bias   = {{5{bias_in[11]}}, bias_in[10:0]};
    wire signed [31:0] product  = s_data * s_weight;

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0; count <= 0; out_valid <= 0; data_out <= 0;
            $display("[%0t] NEURON DEBUG: Reset triggered.", $time); //
        end else if (input_valid) begin
            if (count < NUM_INPUTS - 1) begin
                accumulator <= accumulator + $signed(product);
                count <= count + 1;
                out_valid <= 0;
                $display("[%0t] NEURON STEP %0d: In=%h | W=%h | Prod=%h | Acc=%h", $time, count, data_in, weight_in, product, accumulator);
            end else begin
                final_sum = accumulator + $signed(product) + ($signed(s_bias) << 8);
                
                // Extraction and Masking only; ReLU logic removed
                data_out <= (final_sum >>> SHIFT) & 16'h0FF0; 
                
                out_valid <= 1;
                count <= 0;
                accumulator <= 0;
                $display("[%0t] NEURON RESULT: SUCCESS | Sum=%h | Packed Out=%h", $time, final_sum, (final_sum >>> SHIFT) & 16'h0FF0);
            end
        end else out_valid <= 0;
    end
endmodule