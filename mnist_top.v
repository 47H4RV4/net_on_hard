`timescale 1ns / 1ps

module mnist_top (
    input clk, input rst, input start,
    output reg [15:0] final_prediction,
    output done
);

    wire [31:0] internal_addr; 
    wire l1_run, l2_run, l3_run;
    wire [127:0] l1_valids;
    wire [31:0]  l2_valids;
    wire [9:0]   l3_valids;
    wire [128*16-1:0] l1_bus;
    wire [32*16-1:0]  l2_bus;
    wire [10*16-1:0]  l3_bus;
    wire [15:0] rom_pixel;
    
    reg prediction_done;
    reg search_active;
    reg done_sync;

    global_controller ctrl (
        .clk(clk), .rst(rst), .start_network(start),
        .l1_done(l1_valids[0]), .l2_done(l2_valids[0]), .l3_done(l3_valids[0]),
        .current_addr(internal_addr), .l1_run(l1_run), .l2_run(l2_run), .l3_run(l3_run),
        .network_ready() 
    );

    image_rom img (.clk(clk), .addr(internal_addr[9:0]), .q(rom_pixel));

    // LAYER 1 & 2: Standard Scaling
    nn_layer #(.NUM_INPUTS(784), .NUM_NEURONS(128), .WEIGHT_FILE("layer_1_weights.mif"), .BIAS_FILE("layer_1_biases.mif")) L1 
        (.clk(clk), .rst(rst), .data_in(rom_pixel), .input_valid(l1_run), .local_addr(internal_addr), .out_valids(l1_valids), .layer_out(l1_bus));
    
    nn_layer #(.NUM_INPUTS(128), .NUM_NEURONS(32), .WEIGHT_FILE("layer_2_weights.mif"), .BIAS_FILE("layer_2_biases.mif")) L2 
        (.clk(clk), .rst(rst), .data_in(l1_bus[internal_addr[6:0]*16 +: 16]), .input_valid(l2_run), .local_addr(internal_addr), .out_valids(l2_valids), .layer_out(l2_bus));

    // LAYER 3: Increased Output Scaling (RIGHT_SHIFT=18) to prevent saturation "Ties"
    // This effectively divides the output by 8, allowing us to see differences between 7FFF-level signals
    nn_layer #(.NUM_INPUTS(32), .NUM_NEURONS(10), .WEIGHT_FILE("layer_3_weights.mif"), .BIAS_FILE("layer_3_biases.mif")) L3 
        (.clk(clk), .rst(rst), .data_in(l2_bus[internal_addr[4:0]*16 +: 16]), .input_valid(l3_run), .local_addr(internal_addr), .out_valids(l3_valids), .layer_out(l3_bus));

    // --- REPLACED SOFTMAX WITH DIRECT ARGMAX ---
    integer k;
    reg [15:0] max_val;
    
    always @(posedge clk) begin
        if (rst) begin
            final_prediction <= 0; max_val <= 0;
            prediction_done <= 0; search_active <= 0; done_sync <= 0;
        end else if (l3_valids[0]) begin
            // Trigger search as soon as Layer 3 finishes
            search_active <= 1; 
        end else if (search_active) begin
            max_val = 0;
            $display("[%0t] ARGMAX: Searching Raw Logits (Softmax Bypassed)...", $time);
            for (k = 0; k < 10; k = k + 1) begin
                // Standard logit comparison
                if (l3_bus[k*16 +: 16] >= max_val) begin
                    max_val = l3_bus[k*16 +: 16];
                    final_prediction <= k;
                    $display("  -> Digit %0d Value: %h", k, l3_bus[k*16 +: 16]);
                end
            end
            prediction_done <= 1;
            search_active <= 0;
        end else if (prediction_done) begin
            done_sync <= 1;
            prediction_done <= 0;
        end else begin
            done_sync <= 0;
        end
    end

    assign done = done_sync;
endmodule