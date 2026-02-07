`timescale 1ns / 1ps

module softmax_unit (
    input clk, 
    input rst,
    input [10*16-1:0] neuron_outputs,
    input in_valid,
    output reg [10*16-1:0] softmax_out,
    output reg out_valid
);

    // State definitions
    localparam IDLE = 0, MAX = 1, EXP = 2, SUM = 3, DIV = 4, DONE = 5;
    
    reg [2:0] state;
    reg [3:0] count;
    reg signed [15:0] max_logit;
    reg [15:0] exps [0:9];
    reg [31:0] total_sum;

    // --- FIX: Declare temporary variables as registers at the module level ---
    reg signed [15:0] x_calc;
    reg signed [31:0] x_sq_calc;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; 
            out_valid <= 0;
            count <= 0;
            max_logit <= 16'h8001;
            total_sum <= 0;
            x_calc <= 0;
            x_sq_calc <= 0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    if (in_valid) begin 
                        state <= MAX; 
                        count <= 0; 
                        max_logit <= 16'h8001; 
                    end
                end
                
                MAX: begin // Find Max Logit for mathematical stability
                    if (count < 10) begin
                        if ($signed(neuron_outputs[count*16 +: 16]) > max_logit)
                            max_logit <= neuron_outputs[count*16 +: 16];
                        count <= count + 1;
                    end else begin
                        state <= EXP; 
                        count <= 0;
                    end
                end

                EXP: begin // Taylor Series Expansion: 1 + x + x^2/2
                    if (count < 10) begin
                        // FIX: Perform calculations using the pre-declared registers
                        x_calc = $signed(neuron_outputs[count*16 +: 16]) - max_logit;
                        x_sq_calc = x_calc * x_calc;
                        
                        // Q1.15 math: 1.0 (approx 7FFF) + x + (x^2 / 2)
                        // x_sq is Q2.30, so x_sq[30:16] aligns it to Q15 range
                        exps[count] <= 16'h7FFF + x_calc + x_sq_calc[30:16];
                        
                        count <= count + 1;
                    end else begin
                        state <= SUM; 
                        count <= 0; 
                        total_sum <= 0;
                    end
                end

                SUM: begin // Accumulate total of exponents
                    if (count < 10) begin
                        total_sum <= total_sum + exps[count];
                        count <= count + 1;
                    end else begin
                        state <= DIV; 
                        count <= 0;
                    end
                end

                DIV: begin // Normalize probabilities
                    if (count < 10) begin
                        // Fixed-point division: (Exp * 2^15) / TotalSum
                        if (total_sum[15:0] != 0)
                            softmax_out[count*16 +: 16] <= (exps[count] << 15) / total_sum[15:0];
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