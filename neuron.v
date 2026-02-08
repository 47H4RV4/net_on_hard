`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 4,      // Int4 quantization
    parameter NUM_INPUTS = 784,
    parameter SHIFT = 6          // Normalization shift factor
)(
    input clk,
    input rst,
    input [IN_WIDTH-1:0] data_in,   // Unsigned 4-bit activation
    input [IN_WIDTH-1:0] weight_in, // Signed 4-bit weight
    input input_valid,
    output reg [3:0] data_out,      // Unsigned 4-bit activation out
    output reg out_valid
);

    // 20-bit signed accumulator to prevent overflow
    reg signed [19:0] accumulator;
    reg [31:0] count;

    // Mixed-sign multiplication: unsigned input treated as positive signed * signed weight
    //
    wire signed [19:0] product = $signed({1'b0, data_in}) * $signed(weight_in);

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            count <= 0;
            out_valid <= 0;
            data_out <= 0;
        end else if (input_valid) begin
            if (count < NUM_INPUTS - 1) begin
                accumulator <= accumulator + product;
                count <= count + 1;
                out_valid <= 0;
            end else begin
                // 1. Final Accumulation
                // 2. Normalization: Arithmetic shift right by SHIFT
                // 3. ReLU + Clipping: Keep result in [0, 15] range
                reg signed [19:0] normalized_sum;
                normalized_sum = (accumulator + product) >>> SHIFT;

                if (normalized_sum < 0) 
                    data_out <= 4'd0;       // ReLU
                else if (normalized_sum > 15) 
                    data_out <= 4'd15;      // Positive Saturation
                else 
                    data_out <= normalized_sum[3:0];

                out_valid <= 1;
                count <= 0;
                accumulator <= 0;
            end
        end else begin
            out_valid <= 0;
        end
    end
endmodule