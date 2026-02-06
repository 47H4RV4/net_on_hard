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
    
    // --- THE FIX: Declare the missing variable ---
    reg signed [31:0] final_sum; 

    assign product = $signed(data_in) * $signed(weight_in);

    always @(posedge clk) begin
        if (rst) begin
            accumulator <= 0;
            count <= 0;
            out_valid <= 0;
            data_out <= 0;
        end else begin
            if (input_valid) begin
                if (count < NUM_INPUTS - 1) begin
                    accumulator <= accumulator + product;
                    count <= count + 1;
                    out_valid <= 0;
                end else begin
                    // Final input received: Calculate sum including current product
                    final_sum = accumulator + product + ($signed(bias_in) << 15);
                    
                    // ReLU Activation
                    if (final_sum > 0)
                        data_out <= final_sum[30:15];
                    else
                        data_out <= 0;
                    
                    out_valid <= 1; // Pulse high to signal layer completion
                    count <= 0;     // Reset for next layer/image
                    accumulator <= 0;
                end
            end else begin
                // Ensure out_valid is only high for one cycle 
                out_valid <= 0;
            end
        end
    end
endmodule