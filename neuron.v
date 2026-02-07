`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 16,
    parameter OUT_WIDTH = 16,
    parameter NUM_INPUTS = 784
)(
    input clk,
    input rst,
    input [IN_WIDTH-1:0] data_in,
    input [IN_WIDTH-1:0] weight_in,
    input [IN_WIDTH-1:0] bias_in,
    input input_valid,
    output reg [OUT_WIDTH-1:0] data_out,
    output reg out_valid
);

    // 48-bit wide to prevent overflow during summation of 784 Q2.30 products
    reg signed [47:0] accumulator;
    reg [31:0] count;
    wire signed [31:0] product;
    reg signed [47:0] final_sum;

    // Q1.15 * Q1.15 = Q2.30 result (32 bits)
    assign product = $signed(data_in) * $signed(weight_in);

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            count <= 0;
            out_valid <= 0;
            data_out <= 0;
            $display("[%0t] NEURON DEBUG: Reset triggered.", $time);
        end else if (input_valid) begin
            if (count < NUM_INPUTS - 1) begin
                accumulator <= accumulator + $signed(product);
                count <= count + 1;
                out_valid <= 0;

                // --- DEBUG: Track every 100th accumulation step to monitor progress ---
                if (count % 100 == 0) begin
                    $display("[%0t] NEURON DEBUG: Step %0d | In: %h | W: %h | Prod: %h | Acc: %h", 
                             $time, count, data_in, weight_in, product, accumulator);
                end

            end else begin
                // Final sum: accumulator + last product + bias (shifted to match Q30 fraction)
                final_sum = accumulator + $signed(product) + {{17{bias_in[15]}}, bias_in, 15'b0};
                
                // ReLU + Saturation Logic
                if (final_sum[47]) begin
                    data_out <= 16'h0000; // ReLU: Negative result becomes 0
                    $display("[%0t] NEURON FINISH: Result Negative (%h) -> ReLU forced to 0000", $time, final_sum);
                end else if (|final_sum[46:30]) begin 
                    data_out <= 16'h7FFF; // Saturation: Value >= 1.0 clamped to max
                    $display("[%0t] NEURON FINISH: Result Overflow (%h) -> Saturated to 7FFF", $time, final_sum);
                end else begin
                    // Extract fractional bits [29:15] for Q1.15 output
                    data_out <= {1'b0, final_sum[29:15]};
                    $display("[%0t] NEURON FINISH: Success | Final Sum: %h | Output: %h", $time, final_sum, data_out);
                end
                
                out_valid <= 1;
                count <= 0;
                accumulator <= 0;
            end
        end else begin
            out_valid <= 0;
        end
    end
endmodule