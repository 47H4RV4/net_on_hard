`timescale 1ns / 1ps

module mnist_tb;

    // Inputs
    reg clk;
    reg rst;
    reg start;

    // Outputs
    wire [15:0] final_prediction;
    wire done;

    // Instantiate the Unit Under Test (UUT)
    mnist_top uut (
        .clk(clk), 
        .rst(rst), 
        .start(start), 
        .final_prediction(final_prediction), 
        .done(done)
    );

    // Clock generation (100MHz)
    always #5 clk = ~clk;

    initial begin
        // --- 1. Initialize Signals ---
        clk = 0;
        rst = 1;
        start = 0;

        // Create waveform dump for GTKWave
        $dumpfile("mnist_signals.vcd");
        $dumpvars(0, mnist_tb);

        $display("Starting Neural Network Inference...");
        $display("--------------------------------------");

        // --- 2. Controlled Reset ---
        // Wait for 10 clock cycles before releasing reset
        repeat(10) @(posedge clk);
        rst = 0;
        $display("[%t] Reset released.", $time);

        // --- 3. Synchronized Start ---
        // Wait for 2 more cycles and then pulse 'start' for exactly one clock period
        repeat(2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        $display("[%t] Start signal pulsed.", $time);

        // --- 4. Wait for Done with Timeout ---
        // fork/join is used to wait for either the 'done' signal or a maximum time limit
        fork
            begin
                wait(done);
                $display("--------------------------------------");
                $display("[%t] Inference Complete!", $time);
                $display("Predicted Digit: %d", final_prediction[3:0]); // Showing the 4-bit index
                $display("--------------------------------------");
            end
            begin
                // Timeout after 1,000,000 ns if 'done' never goes high
                #50000000;
                $display("ERROR: Simulation timed out! The 'done' signal was never received.");
            end
        join_any

        #100;
        $finish;
    end

endmodule