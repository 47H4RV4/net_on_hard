`timescale 1ns / 1ps

module mnist_top (
    input clk,
    input rst,
    input start,
    output [10*16-1:0] digit_scores, // High-headroom Q8.8 Scores
    output done
);

    // --- Signal Declarations ---
    wire [31:0] internal_addr; 
    wire l1_run, l2_run, l3_run;
    wire [127:0] l1_valids; wire [31:0] l2_valids; wire [9:0] l3_valids;
    wire [128*16-1:0] l1_bus; wire [511:0] l2_bus; wire [159:0] l3_bus;
    wire [15:0] rom_pixel;
    wire [159:0] sm_bus;
    wire sm_done;

    // --- Global Controller ---
    global_controller ctrl (
        .clk(clk), .rst(rst), .start_network(start),
        .l1_done(l1_valids[0]), .l2_done(l2_valids[0]), .l3_done(l3_valids[0]),
        .current_addr(internal_addr), .l1_run(l1_run), .l2_run(l2_run), .l3_run(l3_run),
        .network_ready() 
    );

    // --- Image ROM ---
    image_rom img (.clk(clk), .addr(internal_addr[9:0]), .q(rom_pixel));

    // --- LAYER 1: Q1.15 * Q1.15 -> Q30 Accumulation ---
    // Extraction point 22 (Bit 30 is 2^0, so bits [37:22] extract Q8.8)
    nn_layer #(.NUM_INPUTS(784), .NUM_NEURONS(128), .SHIFT(22), 
               .WEIGHT_FILE("layer_1_weights.mif"), .BIAS_FILE("layer_1_biases.mif")) L1 (
        .clk(clk), .rst(rst), .data_in(rom_pixel), .input_valid(l1_run), 
        .local_addr(internal_addr), .out_valids(l1_valids), .layer_out(l1_bus)
    );

    // --- LAYER 2: Q8.8 * Q1.15 -> Q23 Accumulation ---
    // Extraction point 15 aligns bit 23 (2^0) to produce Q8.8 result
    nn_layer #(.NUM_INPUTS(128), .NUM_NEURONS(32), .SHIFT(15), 
               .WEIGHT_FILE("layer_2_weights.mif"), .BIAS_FILE("layer_2_biases.mif")) L2 (
        .clk(clk), .rst(rst), .data_in(l1_bus[internal_addr[6:0]*16 +: 16]), .input_valid(l2_run), 
        .local_addr(internal_addr), .out_valids(l2_valids), .layer_out(l2_bus)
    );

    // --- LAYER 3: Q8.8 * Q1.15 -> Q23 Accumulation ---
    nn_layer #(.NUM_INPUTS(32), .NUM_NEURONS(10), .SHIFT(15), 
               .WEIGHT_FILE("layer_3_weights.mif"), .BIAS_FILE("layer_3_biases.mif")) L3 (
        .clk(clk), .rst(rst), .data_in(l2_bus[internal_addr[4:0]*16 +: 16]), .input_valid(l3_run), 
        .local_addr(internal_addr), .out_valids(l3_valids), .layer_out(l3_bus)
    );

    // --- Softmax Unit ---
    softmax_unit sm (
        .clk(clk), .rst(rst), .neuron_outputs(l3_bus), 
        .in_valid(l3_valids[0]), .softmax_out(sm_bus), .out_valid(sm_done)
    );

    // Output all 10 probabilities/logits for testbench analysis
    assign digit_scores = sm_bus;
    assign done = sm_done;

endmodule