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

    reg signed [31:0] accumulator;
    reg [31:0] count;
    wire signed [31:0] product;
    reg signed [31:0] final_sum;

    assign product = $signed(data_in) * $signed(weight_in);

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
                // Calculate final sum including bias
                final_sum = accumulator + product + ($signed(bias_in) << 15);
                
                // --- THE FIX: RELU + SATURATION ---
                if (final_sum <= 0) begin
                    data_out <= 0; // ReLU
                end else if (final_sum[31:30] != 2'b00) begin
                    // Overflow occurred (value > 1.0)
                    data_out <= 16'h7FFF; // Saturate to max positive Q1.15
                end else begin
                    data_out <= final_sum[30:15]; // Normal positive value
                end
                
                $display("[%0t] NEURON DEBUG: Finished %0d inputs. Result: %h", $time, NUM_INPUTS, data_out);
                out_valid <= 1;
                count <= 0;
                accumulator <= 0;
            end
        end else begin
            out_valid <= 0;
        end
    end
endmodule