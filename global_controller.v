`timescale 1ns / 1ps

module global_controller (
    input clk,
    input rst,
    input start_network,
    input l1_done,
    input l2_done,
    input l3_done,
    output reg [31:0] current_addr,
    output reg l1_run,
    output reg l2_run,
    output reg l3_run,
    output reg network_ready
);

    localparam IDLE   = 3'b000;
    localparam LAYER1 = 3'b001;
    localparam LAYER2 = 3'b010;
    localparam LAYER3 = 3'b011;
    localparam DONE   = 3'b100;

    reg [2:0] state;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            current_addr <= 0;
            l1_run <= 0; l2_run <= 0; l3_run <= 0;
            network_ready <= 0;
        end else begin
            case (state)
                IDLE: begin
                    network_ready <= 0;
                    if (start_network) begin
                        state <= LAYER1;
                        current_addr <= 0;
                    end
                end

                LAYER1: begin
                    l1_run <= 1; // KEEP THIS HIGH 
                    if (current_addr < 783) 
                        current_addr <= current_addr + 1;
                    
                    if (l1_done) begin // Wait for the neuron pulse
                        state <= LAYER2;
                        current_addr <= 0;
                        l1_run <= 0; // NOW turn it off
                    end
                end

                LAYER2: begin
                    l2_run <= 1; // KEEP THIS HIGH 
                    if (current_addr < 127) 
                        current_addr <= current_addr + 1;
                    
                    if (l2_done) begin
                        state <= LAYER3;
                        current_addr <= 0;
                        l2_run <= 0;
                    end
                end

                LAYER3: begin
                    l3_run <= 1; // KEEP THIS HIGH 
                    if (current_addr < 31) 
                        current_addr <= current_addr + 1;
                    
                    if (l3_done) begin
                        state <= DONE;
                        current_addr <= 0;
                        l3_run <= 0;
                    end
                end

                DONE: begin
                    network_ready <= 1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule