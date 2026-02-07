`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 16,
    parameter OUT_WIDTH = 16,
    parameter NUM_INPUTS = 784,
    parameter OUT_SHIFT = 15 // Standard extraction for Q1.15
)(
    input clk, input rst,
    input [IN_WIDTH-1:0] data_in,
    input [IN_WIDTH-1:0] weight_in,
    input [IN_WIDTH-1:0] bias_in,
    input input_valid,
    output reg [OUT_WIDTH-1:0] data_out,
    output reg out_valid
);

    reg signed [47:0] accumulator;
    reg [31:0] count;
    wire signed [31:0] product = $signed(data_in) * $signed(weight_in);
    reg signed [47:0] final_sum;

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0; count <= 0; out_valid <= 0; data_out <= 0;
            $display("[%0t] NEURON DEBUG: Reset triggered.", $time);
        end else if (input_valid) begin
            if (count < NUM_INPUTS - 1) begin
                accumulator <= accumulator + $signed(product);
                count <= count + 1;
                out_valid <= 0;
                $display("[%0t] NEURON STEP %0d: Acc=%h", $time, count, accumulator);
            end else begin
                // Final sum calculation with bias alignment
                final_sum = accumulator + $signed(product) + {{17{bias_in[15]}}, bias_in, 15'b0};
                
                // ReLU + Headroom Scaling Extraction
                if (final_sum[47]) begin
                    data_out <= 16'h0000; // ReLU
                end else begin
                    // Check for overflow relative to the target OUT_SHIFT
                    if (|final_sum[46 : OUT_SHIFT+15]) begin
                        data_out <= 16'h7FFF; // Saturation
                    end else begin
                        // Extract with higher shift to provide headroom
                        data_out <= {1'b0, final_sum[(OUT_SHIFT+14) : OUT_SHIFT]};
                    end
                end
                $display("[%0t] NEURON FINISH: Sum=%h | Out=%h", $time, final_sum, data_out);
                out_valid <= 1;
                count <= 0; accumulator <= 0;
            end
        end else out_valid <= 0;
    end
endmodule