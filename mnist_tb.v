`timescale 1ns / 1ps

module mnist_tb;

    reg clk;
    reg rst;
    reg start;
    wire [159:0] scores; 
    wire done;

    mnist_top uut (
        .clk(clk), .rst(rst), .start(start), 
        .digit_scores(scores), .done(done)
    );

    always #5 clk = ~clk;

    integer i;
    reg [15:0] max_score;
    integer predicted_digit;
    reg [15:0] current_score;

    initial begin
        clk = 0; rst = 1; start = 0;

        $dumpfile("mnist_signals.vcd");
        $dumpvars(0, mnist_tb);

        $display("Starting Neural Network Inference (Argmax-in-TB Mode)...");
        $display("---------------------------------------------------------");

        repeat(10) @(posedge clk);
        rst = 0;
        $display("[%0t] TB: Global Reset released.", $time);

        repeat(5) @(posedge clk);
        
        $display("[%0t] TB: Asserting Start Signal...", $time);
        start = 1;
        repeat(2) @(posedge clk); 
        start = 0;

        fork
            begin
                // --- TESTBENCH-SIDE ARGMAS ---
                wait(done);
                $display("---------------------------------------------------------");
                $display("[%0t] TB: SUCCESS - Done signal received!", $time);
                $display("Analyzing Q8.8 Final Scores (Hex):");
                
                max_score = 16'h0000;
                predicted_digit = 0;
                
                for (i = 0; i < 10; i = i + 1) begin
                    current_score = scores[i*16 +: 16];
                    $display("  Digit %0d Score: %h", i, current_score);
                    
                    // Comparison to find the highest probability
                    if (current_score >= max_score) begin
                        max_score = current_score;
                        predicted_digit = i;
                    end
                end
                
                $display("---------------------------------------------------------");
                $display(">>> FINAL PREDICTED DIGIT: %0d <<<", predicted_digit);
                $display("---------------------------------------------------------");
                #100;
                $finish;
            end
            
            begin : heartbeat_monitor
                forever begin
                    #1000000;
                    if (!done)
                        $display("[%0t] TB: Simulation ongoing...", $time);
                    else
                        disable heartbeat_monitor;
                end
            end

            begin
                #20000000; // 20ms Timeout
                $display("[%0t] FATAL ERROR: Simulation Timed Out!", $time);
                $finish;
            end
        join_any
    end
endmodule