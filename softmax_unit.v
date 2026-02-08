`timescale 1ns / 1ps

module softmax_unit (
    input clk, input rst,
    input [10*16-1:0] neuron_outputs,
    input in_valid,
    output reg [10*16-1:0] softmax_out,
    output reg out_valid
);

    localparam IDLE=0, MAX=1, EXP=2, SUM=3, DIV=4, DONE=5;
    reg [2:0] state;
    reg [3:0] count;
    reg signed [15:0] max_logit;
    reg [15:0] exps [0:9];
    reg [31:0] total_sum;
    reg signed [15:0] x_calc;
    reg signed [31:0] x_sq_calc;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; out_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    if (in_valid) begin state <= MAX; count <= 0; max_logit <= 16'h8001; end
                end
                
                MAX: begin // Find Max for stability (Q8.8)
                    if (count < 10) begin
                        if ($signed(neuron_outputs[count*16 +: 16]) > max_logit)
                            max_logit <= neuron_outputs[count*16 +: 16];
                        count <= count + 1;
                    end else begin state <= EXP; count <= 0; end
                end

                EXP: begin // Q8.8 Taylor Series: 1.0 (0100) + x + x^2/2
                    if (count < 10) begin
                        x_calc = $signed(neuron_outputs[count*16 +: 16]) - max_logit;
                        x_sq_calc = x_calc * x_calc; // Q8.8 * Q8.8 = Q16.16
                        
                        // Q8.8 math: 1.0 (0100) + x + (x_sq / 512)
                        // x_sq_calc is Q16.16; shifting by 9 scales to Q8.8 and divides by 2
                        exps[count] <= 16'h0100 + x_calc + (x_sq_calc >>> 9);
                        count <= count + 1;
                    end else begin state <= SUM; count <= 0; total_sum <= 0; end
                end

                SUM: begin 
                    if (count < 10) begin
                        total_sum <= total_sum + exps[count];
                        count <= count + 1;
                    end else begin state <= DIV; count <= 0; end
                end

                DIV: begin // Normalize for Q8.8 output
                    if (count < 10) begin
                        // Shift left by 8 to maintain Q8.8 precision during division
                        if (total_sum[15:0] != 0)
                            softmax_out[count*16 +: 16] <= (exps[count] << 8) / total_sum[15:0];
                        else
                            softmax_out[count*16 +: 16] <= 16'h0000;
                        count <= count + 1;
                    end else state <= DONE;
                end

                DONE: begin out_valid <= 1; state <= IDLE; end
            endcase
        end
    end
endmodule