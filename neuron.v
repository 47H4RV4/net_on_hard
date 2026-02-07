`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 16,
    parameter OUT_WIDTH = 16,
    parameter NUM_INPUTS = 784,
    parameter OUT_SHIFT = 22 // High-precision extraction point (e.g., 22 for Q30->Q8.8)
)(
    input clk,
    input rst,
    input [IN_WIDTH-1:0] data_in,   // Q1.15
    input [IN_WIDTH-1:0] weight_in, // Q1.15
    input [IN_WIDTH-1:0] bias_in,   // Q1.15
    input input_valid,
    output reg [OUT_WIDTH-1:0] data_out,
    output reg out_valid
);

    reg signed [47:0] accumulator;
    reg [31:0] count;
    wire signed [31:0] product;
    reg signed [47:0] final_sum;
    reg [47:0] rounded_sum;

    assign product = $signed(data_in) * $signed(weight_in); // Q2.30

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            count <= 0;
            out_valid <= 0;
            data_out <= 0;
            rounded_sum <= 0;
            $display("[%0t] NEURON DEBUG: Reset triggered.", $time); //
        end else if (input_valid) begin
            if (count < NUM_INPUTS - 1) begin
                accumulator <= accumulator + $signed(product);
                count <= count + 1;
                out_valid <= 0;

                // --- PROGRESS DISPLAY: Tracks every 100th pixel to monitor accumulation ---
                $display("[%0t] NEURON STEP %0d: In=%h | W=%h | Prod=%h | Acc=%h", 
                             $time, count, data_in, weight_in, product, accumulator); //
                

            end else begin
                // Final sum calculation with bias alignment (Q1.15 shifted to match Q30 fraction)
                final_sum = accumulator + $signed(product) + {{17{bias_in[15]}}, bias_in, 15'b0}; //
                
                // ReLU + Rounding + Saturation Logic
                if (final_sum[47]) begin
                    data_out <= {OUT_WIDTH{1'b0}}; // ReLU
                    $display("[%0t] NEURON RESULT: Negative Sum (%h) -> ReLU forced to 0000", $time, final_sum); //
                end else begin
                    // TACKLE: Round-to-Nearest by adding 1/2 of the LSB before shifting
                    rounded_sum = final_sum + (1 << (OUT_SHIFT - 1));
                    
                    // Check for integer overflow (Saturation above 127.0)
                    if (|rounded_sum[46 : OUT_SHIFT + OUT_WIDTH - 1]) begin
                        data_out <= {1'b0, {(OUT_WIDTH-1){1'b1}}}; // 7FFF
                        $display("[%0t] NEURON RESULT: OVERFLOW (%h) -> Saturated to 7FFF", $time, final_sum); //
                    end else begin
                        // Extraction: Returns the requested OUT_WIDTH based on the SHIFT
                        data_out <= rounded_sum[(OUT_SHIFT + OUT_WIDTH - 1) : OUT_SHIFT];
                        $display("[%0t] NEURON RESULT: SUCCESS | Sum=%h | Output=%h", $time, final_sum, rounded_sum[(OUT_SHIFT + OUT_WIDTH - 1) : OUT_SHIFT]); //
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