`timescale 1ns / 1ps

module softmax_unit (
    input clk,
    input rst,
    input [10*16-1:0] neuron_outputs,
    input in_valid,
    output reg [10*16-1:0] softmax_out,
    output reg out_valid
);

    // --- State Definitions (Derived from maomran reference) ---
    //
    localparam IDLE   = 3'b000;
    localparam MAX    = 3'b001; // Stabilizer (Essential for Fixed-Point)
    localparam EXP    = 3'b010; // Taylor Series e^x
    localparam SUM    = 3'b011; // Summation of Exponents
    localparam DIV    = 3'b100; // Normalization (Division)
    localparam DONE   = 3'b101;

    reg [2:0] state;
    reg [3:0] count;
    reg [15:0] max_logit;
    reg [15:0] stabilized_logits [0:9];
    reg [15:0] exponents [0:9];
    reg [31:0] sum_exponents; // Q16.16 to prevent overflow
    
    // Fixed-Point Taylor Series math: e^x approx 1 + x + x^2/2
    wire [31:0] x_sq = ($signed(stabilized_logits[count]) * $signed(stabilized_logits[count]));
    wire [15:0] x_sq_over_2 = x_sq[30:16]; // Correctly shift for x^2 / 2

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE; out_valid <= 0; sum_exponents <= 0;
        end else begin
            case (state)
                IDLE: if (in_valid) begin
                    state <= MAX;
                    count <= 0;
                    max_logit <= 16'h8000; // Most negative
                end

                // Step 1: Find Max (Reference Stability Trick)
                MAX: begin
                    if (count < 10) begin
                        if ($signed(neuron_outputs[count*16 +: 16]) > $signed(max_logit))
                            max_logit <= neuron_outputs[count*16 +: 16];
                        count <= count + 1;
                    end else begin
                        state <= EXP;
                        count <= 0;
                    end
                end

                // Step 2: Exponential (Taylor Series reference)
                EXP: begin
                    if (count < 10) begin
                        // Stabilize x_i = (logit - max). Ensures result is always <= 0.
                        // exp(negative) is always 0.0 to 1.0, which fits in Q1.15.
                        stabilized_logits[count] <= neuron_outputs[count*16 +: 16] - max_logit;
                        
                        // Taylor Series: 1 + x + x^2/2
                        // Q1.15 representation of '1' is 7FFF.
                        exponents[count] <= 16'h7FFF + stabilized_logits[count] + x_sq_over_2;
                        
                        count <= count + 1;
                        state <= EXP; 
                    end else begin
                        state <= SUM;
                        count <= 0;
                        sum_exponents <= 0;
                    end
                end

                // Step 3: Sequential Addition
                SUM: begin
                    if (count < 10) begin
                        sum_exponents <= sum_exponents + exponents[count];
                        count <= count + 1;
                    end else begin
                        state <= DIV;
                        count <= 0;
                    end
                end

                // Step 4: Normalization (Division)
                DIV: begin
                    if (count < 10) begin
                        // Q1.15 Division: (Exp * 2^15) / Sum
                        softmax_out[count*16 +: 16] <= (exponents[count] << 15) / sum_exponents[15:0];
                        count <= count + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    out_valid <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule