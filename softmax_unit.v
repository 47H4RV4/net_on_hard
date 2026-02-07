`timescale 1ns / 1ps

module softmax_unit (
    input clk, input rst,
    input [10*16-1:0] neuron_outputs,
    input in_valid,
    output reg [10*16-1:0] softmax_out,
    output reg out_valid
);
    reg [3:0] state;
    reg [31:0] sum_exponents; 
    reg [15:0] exp_results [0:9];
    reg [3:0] count;
    wire [15:0] exp_q, recip_q;
    reg [9:0] lut_addr;

    exp_lut e_lut (.clk(clk), .addr(lut_addr), .q(exp_q));
    reciprocal_lut r_lut (.clk(clk), .addr(sum_exponents[20:11]), .q(recip_q));

    always @(posedge clk) begin
        if (rst) begin
            state <= 0; out_valid <= 0; count <= 0; sum_exponents <= 0;
        end else begin
            case (state)
                0: if (in_valid) begin state <= 1; count <= 0; sum_exponents <= 0; end
                1: begin // Address Setup
                    if (count < 10) begin
                        current_val = neuron_outputs[count*16 +: 16];
                        if (current_val[15]) begin // Negative input
                            lut_addr <= 0; // exp(negative) maps to small value
                        end else begin
                            // Use high bits of fraction for LUT index
                            lut_addr <= current_val[14:5]; 
                        end
                        state <= 2;
                    end else begin
                        state <= 3;
                    end
                end
                2: begin 
                    exp_results[count] <= exp_q;
                    sum_exponents <= sum_exponents + exp_q;
                    count <= count + 1;
                    state <= 1;
                end
                3: begin 
                    for (int i=0; i<10; i++)
                        softmax_out[i*16 +: 16] <= (exp_results[i] * recip_q) >> 15;
                    state <= 4; 
                end
                4: begin
                    out_valid <= 1; // Register output stability
                    state <= 5;
                end
                5: begin out_valid <= 0; state <= 0; end
            endcase
        end
    end
endmodule