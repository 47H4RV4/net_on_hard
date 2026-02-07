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
    reg [31:0] sum_exponents; // Wide enough to prevent overflow
    reg [15:0] exp_results [0:9];
    reg [3:0] count;
    
    wire [15:0] exp_q;
    wire [15:0] recip_q;
    
    // Declared registers for stability
    reg [9:0] lut_addr;
    reg [15:0] current_val; 

    exp_lut e_lut (.clk(clk), .addr(lut_addr), .q(exp_q));
    // Fixed reciprocal indexing using upper magnitude bits
    reciprocal_lut r_lut (.clk(clk), .addr(sum_exponents[20:11]), .q(recip_q));

    always @(posedge clk) begin
        if (rst) begin
            state <= 0; out_valid <= 0; count <= 0; sum_exponents <= 0;
            lut_addr <= 0; current_val <= 0;
        end else begin
            case (state)
                0: if (in_valid) begin 
                    state <= 1; count <= 0; sum_exponents <= 0; 
                end
                
                1: begin // Fixed LUT Address Mapping
                    if (count < 10) begin
                        current_val = neuron_outputs[count*16 +: 16];
                        if (current_val[15]) begin
                            lut_addr <= 0; // Negative input -> minimal exp
                        end else begin
                            // Map magnitude bits (14:5) to LUT address
                            lut_addr <= current_val[14:5]; 
                        end
                        state <= 2;
                    end else state <= 3;
                end

                2: begin // Accumulation
                    exp_results[count] <= exp_q;
                    sum_exponents <= sum_exponents + exp_q;
                    count <= count + 1;
                    state <= 1;
                end

                3: begin // Softmax calculation
                    for (int i=0; i<10; i++) begin
                        softmax_out[i*16 +: 16] <= (exp_results[i] * recip_q) >> 15;
                    end
                    state <= 4; // Stabilization cycle
                end

                4: begin
                    out_valid <= 1; // Pulse valid only after data is registered
                    state <= 5;
                end

                5: begin
                    out_valid <= 0;
                    state <= 0;
                end
            endcase
        end
    end
endmodule