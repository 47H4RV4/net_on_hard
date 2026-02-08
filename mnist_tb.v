`timescale 1ns / 1ps

module mnist_tb;
    reg clk;
    reg rst;
    reg start;
    wire [3:0] predicted_class; // Updated to match argmax output
    wire done;

    // Unit Under Test (UUT)
    mnist_top uut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .predicted_class(predicted_class),
        .done(done)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        // Initialize
        rst = 1;
        start = 0;
        #100;
        rst = 0;
        #20;
        
        // Start Inference
        start = 1;
        #10;
        start = 0;

        // Wait for Completion
        wait(done);
        
        $display("-----------------------------------------");
        $display("Inference Complete!");
        $display("Hardware Predicted Digit: %d", predicted_class);
        $display("-----------------------------------------");
        
        #100;
        $finish;
    end
endmodule