`timescale 1ns / 1ps

module mnist_top (
    input clk,
    input rst,
    input start,
    output [10*16-1:0] digit_scores, // Corrected: Match the testbench port name
    output done
);

    // --- Signal Declarations ---
    wire [31:0] internal_addr; 
    wire l1_run, l2_run, l3_run;
    wire [127:0] l1_valids;
    wire [31:0]  l2_valids;
    wire [9:0]   l3_valids;
    wire [128*16-1:0] l1_bus;
    wire [32*16-1:0]  l2_bus;
    wire [10*16-1:0]  l3_bus;
    wire [15:0] rom_pixel;
    wire [10*16-1:0] sm_bus;
    wire sm_done;

    // --- Global Controller ---
    global_controller ctrl (
        .clk(clk), .rst(rst), .start_network(start),
        .l1_done(l1_valids[0]), .l2_done(l2_valids[0]), .l3_done(l3_valids[0]),
        .current_addr(internal_addr), .l1_run(l1_run), .l2_run(l2_run), .l3_run(l3_run),
        .network_ready() 
    );

    // --- Image Memory ---
    image_rom img (.clk(clk), .addr(internal_addr[9:0]), .q(rom_pixel));

    // --- Neural Layers (Scaling applied for stability) ---
    nn_layer #(.NUM_INPUTS(784), .NUM_NEURONS(128), .SHIFT(19), 
               .WEIGHT_FILE("layer_1_weights.mif"), .BIAS_FILE("layer_1_biases.mif")) L1 (
        .clk(clk), .rst(rst), .data_in(rom_pixel), .input_valid(l1_run), 
        .local_addr(internal_addr), .out_valids(l1_valids), .layer_out(l1_bus)
    );

    nn_layer #(.NUM_INPUTS(128), .NUM_NEURONS(32), .SHIFT(17), 
               .WEIGHT_FILE("layer_2_weights.mif"), .BIAS_FILE("layer_2_biases.mif")) L2 (
        .clk(clk), .rst(rst), .data_in(l1_bus[internal_addr[6:0]*16 +: 16]), .input_valid(l2_run), 
        .local_addr(internal_addr), .out_valids(l2_valids), .layer_out(l2_bus)
    );

    nn_layer #(.NUM_INPUTS(32), .NUM_NEURONS(10), .SHIFT(15), 
               .WEIGHT_FILE("layer_3_weights.mif"), .BIAS_FILE("layer_3_biases.mif")) L3 (
        .clk(clk), .rst(rst), .data_in(l2_bus[internal_addr[4:0]*16 +: 16]), .input_valid(l3_run), 
        .local_addr(internal_addr), .out_valids(l3_valids), .layer_out(l3_bus)
    );

    // --- Softmax Unit (Brings all scores to probabilities) ---
    softmax_unit sm (
        .clk(clk), .rst(rst), .neuron_outputs(l3_bus), 
        .in_valid(l3_valids[0]), .softmax_out(sm_bus), .out_valid(sm_done)
    );

    // --- Connections to Testbench ---
    // digit_scores now provides all 10 results for Argmax to be done in TB
    assign digit_scores = sm_bus;
    assign done = sm_done;

endmodule