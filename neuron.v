`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 16,
    parameter OUT_WIDTH = 16,
    parameter NUM_INPUTS = 784,
    parameter OUT_SHIFT = 15 // Controls the bit-extraction range
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

    reg signed [47:0] accumulator;
    reg [31:0] count;
    wire signed [31:0] product;
    reg signed [47:0] final_sum;

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

                // --- VERBOSE STATE DISPLAY (Every 100th pixel to prevent log bloat) ---
                if (count % 100 == 0) begin
                    $display("[%0t] NEURON STEP %0d: In=%h | W=%h | Prod=%h | Acc=%h", 
                             $time, count, data_in, weight_in, product, accumulator);
                end

            end else begin
                // Final sum calculation with bias alignment
                final_sum = accumulator + $signed(product) + {{17{bias_in[15]}}, bias_in, 15'b0};
                
                // ReLU + Saturation Logic with State Reporting
                if (final_sum[47]) begin
                    data_out <= 16'h0000; // ReLU
                    $display("[%0t] NEURON RESULT: Negative Sum (%h) -> Output 0000", $time, final_sum);
                end else begin
                    // Extract based on the OUT_SHIFT range
                    if (|final_sum[46 : OUT_SHIFT+15]) begin
                        data_out <= 16'h7FFF; // Saturate
                        $display("[%0t] NEURON RESULT: OVERFLOW (%h) -> Saturated to 7FFF", $time, final_sum);
                    end else begin
                        data_out <= {1'b0, final_sum[(OUT_SHIFT+14) : OUT_SHIFT]};
                        $display("[%0t] NEURON RESULT: SUCCESS | Sum=%h | Output=%h", $time, final_sum, data_out);
                    end
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