`timescale 1ns / 1ps

module softmax_unit (
    input clk,
    input rst,
    input [10*16-1:0] neuron_outputs,
    input in_valid,
    output reg [10*16-1:0] softmax_out,
    output reg out_valid
);

    reg [3:0] state;
    reg [15:0] sum_exponents;
    reg [15:0] exp_results [0:9];
    reg [3:0] count;
    
    wire [15:0] exp_q;
    wire [15:0] recip_q;
    reg [9:0] lut_addr;
    reg [15:0] current_val; // Helper reg for readability

    // LUT Instances
    exp_lut e_lut (.clk(clk), .addr(lut_addr), .q(exp_q));
    // Note: Reciprocal LUT usually expects a normalized sum, but we keep existing logic
    reciprocal_lut r_lut (.clk(clk), .addr(sum_exponents[15:6]), .q(recip_q));

    always @(posedge clk) begin
        if (rst) begin
            state <= 0;
            out_valid <= 0;
            count <= 0;
            sum_exponents <= 0;
        end else begin
            case (state)
                0: if (in_valid) begin 
                    state <= 1;
                    count <= 0; 
                    sum_exponents <= 0;
                end
                
                1: begin // Address Setup & Clamping
                    if (count < 10) begin
                        current_val = neuron_outputs[count*16 +: 16];
                        
                        // FIX: Handle Signed Inputs
                        if (current_val[15] == 1) begin
                            // Input is negative. e^x should be small. 
                            // Map to index 0 (approx 1.0 or smallest table entry)
                            lut_addr <= 0; 
                        end else begin
                            // Input is positive. Clamp to max 1023.
                            if (current_val > 1023) 
                                lut_addr <= 1023;
                            else 
                                lut_addr <= current_val[9:0];
                        end
                        state <= 2;
                    end else begin
                        state <= 3;
                    end
                end

                2: begin // Read LUT & Accumulate
                    exp_results[count] <= exp_q;
                    sum_exponents <= sum_exponents + exp_q;
                    count <= count + 1;
                    state <= 1;
                end

                3: begin // Normalization (Division)
                    for (int i=0; i<10; i++) begin
                        // Q15 * Q15 = Q30 >> 15 = Q15
                        softmax_out[i*16 +: 16] <= (exp_results[i] * recip_q) >> 15;
                    end
                    out_valid <= 1;
                    state <= 4;
                end

                4: begin
                    out_valid <= 0;
                    state <= 0;
                end
            endcase
        end
    end
endmodule