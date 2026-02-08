`timescale 1ns / 1ps

module softmax_unit (
    input clk, input rst,
    input [10*16-1:0] neuron_outputs, // Packed 0000siii.ffff0000
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

    // Helper to sign-extend the packed format for calculations
    function signed [15:0] sign_ext;
        input [15:0] in;
        begin
            sign_ext = {{5{in[11]}}, in[10:0]};
        end
    endfunction

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; out_valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    out_valid <= 0;
                    if (in_valid) begin 
                        state <= MAX; 
                        count <= 0; 
                        max_logit <= 16'hF800; // Large negative in packed format
                    end
                end
                
                MAX: begin // Stability: find max logit using sign-extended values
                    if (count < 10) begin
                        if (sign_ext(neuron_outputs[count*16 +: 16]) > max_logit)
                            max_logit <= sign_ext(neuron_outputs[count*16 +: 16]);
                        count <= count + 1;
                    end else begin state <= EXP; count <= 0; end
                end

                EXP: begin // Q4.4 Taylor Series: e^x approx 1 + x + x^2/2
                    if (count < 10) begin
                        x_calc = sign_ext(neuron_outputs[count*16 +: 16]) - max_logit;
                        x_sq_calc = x_calc * x_calc; // Result is scale 2^16
                        
                        // FIX: 1.0 in packed Q4.4 is 0x0100 (256).
                        // x_sq_calc is scale 2^16. Right shift by 9 scales to 2^8 and divides by 2.
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

                DIV: begin // Normalization for Q4.4 output
                    if (count < 10) begin
                        // Shift left by 8 to maintain Q4.4 scale (bit 8 = 1.0) during division
                        if (total_sum != 0) begin
                            // Calculate and mask to ensure 0000 padding
                            softmax_out[count*16 +: 16] <= ((exps[count] << 8) / total_sum) & 16'h0FF0;
                        end else begin
                            softmax_out[count*16 +: 16] <= 16'h0000;
                        end
                        count <= count + 1;
                    end else state <= DONE;
                end

                DONE: begin out_valid <= 1; state <= IDLE; end
            endcase
        end
    end
endmodule