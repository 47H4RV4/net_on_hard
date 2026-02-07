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
                IDLE: if (in_valid) begin state <= MAX; count <= 0; max_logit <= 16'h8001; end
                
                MAX: begin // Stability step: find the largest input
                    if (count < 10) begin
                        if ($signed(neuron_outputs[count*16 +: 16]) > max_logit)
                            max_logit <= neuron_outputs[count*16 +: 16];
                        count <= count + 1;
                    end else begin state <= EXP; count <= 0; end
                end

                EXP: begin // Taylor Series Expansion: 1 + x + x^2/2
                    if (count < 10) begin
                        x_calc = $signed(neuron_outputs[count*16 +: 16]) - max_logit;
                        x_sq_calc = x_calc * x_calc;
                        // Q1.15 Taylor Series: 1.0 (7FFF) + x + x^2/2
                        exps[count] <= 16'h7FFF + x_calc + x_sq_calc[30:16];
                        count <= count + 1;
                    end else begin state <= SUM; count <= 0; total_sum <= 0; end
                end

                SUM: begin // Sum all exponents for normalization
                    if (count < 10) begin
                        total_sum <= total_sum + exps[count];
                        count <= count + 1;
                    end else begin state <= DIV; count <= 0; end
                end

                DIV: begin // Normalization: Prob = exp(x_i) / sum(exp)
                    if (count < 10) begin
                        if (total_sum[15:0] != 0)
                            softmax_out[count*16 +: 16] <= (exps[count] << 15) / total_sum[15:0];
                        count <= count + 1;
                    end else state <= DONE;
                end

                DONE: begin out_valid <= 1; state <= IDLE; end
            endcase
        end
    end
endmodule