`timescale 1ns / 1ps

module softmax_unit (
    input clk, 
    input rst,
    input [10*16-1:0] neuron_outputs,
    input in_valid,
    output reg [10*16-1:0] softmax_out,
    output reg out_valid
);

    // State definitions for stable softmax pipeline
    localparam IDLE = 0, MAX = 1, EXP = 2, SUM = 3, DIV = 4, DONE = 5;
    
    reg [2:0] state;
    reg [3:0] count;
    reg signed [15:0] max_logit;
    reg [15:0] exps [0:9];
    reg [31:0] total_sum;

    // Temporary registers for Taylor Series math
    reg signed [15:0] x_calc;
    reg signed [31:0] x_sq_calc;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; out_valid <= 0; count <= 0;
            max_logit <= 16'h8001; total_sum <= 0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    if (in_valid) begin 
                        state <= MAX; count <= 0; max_logit <= 16'h8001; 
                    end
                end
                
                MAX: begin // Find Max Logit for stability (Ensures exp input <= 0)
                    if (count < 10) begin
                        if ($signed(neuron_outputs[count*16 +: 16]) > max_logit)
                            max_logit <= neuron_outputs[count*16 +: 16];
                        count <= count + 1;
                    end else begin
                        state <= EXP; count <= 0;
                    end
                end

                EXP: begin // Taylor Series: e^x approx 1 + x + x^2/2
                    if (count < 10) begin
                        x_calc = $signed(neuron_outputs[count*16 +: 16]) - max_logit;
                        x_sq_calc = x_calc * x_calc; // Q8.8 * Q8.8 = Q16.16
                        
                        // Q8.8 math: 1.0 (16'h0100) + x + (x^2 / 2)
                        // x_sq_calc is Q16.16. Shifting right by 9 bits scales it to Q8.8 
                        // and performs the division by 2 simultaneously.
                        exps[count] <= 16'h0100 + x_calc + (x_sq_calc >> 9);
                        
                        count <= count + 1;
                    end else begin
                        state <= SUM; count <= 0; total_sum <= 0;
                    end
                end

                SUM: begin // Accumulate total sum of exponents
                    if (count < 10) begin
                        total_sum <= total_sum + exps[count];
                        count <= count + 1;
                    end else begin
                        state <= DIV; count <= 0;
                    end
                end

                DIV: begin // Normalize probabilities: Prob = Exp / TotalSum
                    if (count < 10) begin
                        // Fixed-point division: (Exp * 2^8) / TotalSum to maintain Q8.8
                        if (total_sum[15:0] != 0)
                            softmax_out[count*16 +: 16] <= (exps[count] << 8) / total_sum[15:0];
                        else
                            softmax_out[count*16 +: 16] <= 16'h0000;
                        count <= count + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    out_valid <= 1; // Pulse high for one cycle
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule