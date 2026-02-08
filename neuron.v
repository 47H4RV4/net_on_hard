`timescale 1ns / 1ps

module neuron #(
    parameter IN_WIDTH = 16,
    parameter NUM_INPUTS = 784,
    parameter SHIFT = 8 // Extraction point for the Packed Q4.4 format
)(
    input clk,
    input rst,
    input [IN_WIDTH-1:0] data_in,   // Packed 0000siii.ffff0000
    input [IN_WIDTH-1:0] weight_in, // Packed 0000siii.ffff0000
    input [IN_WIDTH-1:0] bias_in,   // Packed 0000siii.ffff0000
    input input_valid,
    output reg [15:0] data_out,     // Packed 0000siii.ffff0000
    output reg out_valid
);

    reg signed [47:0] accumulator;
    reg [31:0] count;
    reg signed [47:0] final_sum;

    // TACKLE: Manually sign-extend the 12-bit packed data (bits [11:0]) to 16 bits.
    // Bit 11 is the sign bit 's'.
    wire signed [15:0] s_data   = {{5{data_in[11]}}, data_in[10:0]};
    wire signed [15:0] s_weight = {{5{weight_in[11]}}, weight_in[10:0]};
    wire signed [15:0] s_bias   = {{5{bias_in[11]}}, bias_in[10:0]};

    // Product of two Q4.4 packed numbers (scale 2^8) results in scale 2^16
    wire signed [31:0] product = s_data * s_weight;

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            count <= 0;
            out_valid <= 0;
            data_out <= 0;
            $display("[%0t] NEURON DEBUG: Reset triggered.", $time); //
        end else if (input_valid) begin
            if (count < NUM_INPUTS - 1) begin
                accumulator <= accumulator + $signed(product);
                count <= count + 1;
                out_valid <= 0;

                // Progress monitor for the neurons
                $display("[%0t] NEURON STEP %0d: In=%h | W=%h | Prod=%h | Acc=%h", 
                             $time, count, data_in, weight_in, product, accumulator);

            end else begin
                // 1. Align Bias (Scale 2^8) with Accumulator (Scale 2^16) by shifting left by 8
                final_sum = accumulator + $signed(product) + ($signed(s_bias) << 8);
                
                // 2. ReLU Activation + Extraction logic
                if (final_sum[47]) begin
                    data_out <= 16'h0000; // ReLU
                    $display("[%0t] NEURON RESULT: Negative Sum (%h) -> ReLU 0000", $time, final_sum);
                end else begin
                    // 3. Normalize: Shift right by SHIFT to return to packed scale
                    // 4. Mask: Apply 0x0FF0 to ensure 0000 padding in bits [15:12] and [3:0]
                    data_out <= (final_sum >>> SHIFT) & 16'h0FF0; 
                    
                    $display("[%0t] NEURON RESULT: SUCCESS | Sum=%h | Packed Out=%h", 
                             $time, final_sum, (final_sum >>> SHIFT) & 16'h0FF0);
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