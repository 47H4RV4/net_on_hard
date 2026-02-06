`timescale 1ns / 1ps

module mnist_tb;

    reg clk;
    reg rst;
    reg start;
    wire [15:0] final_prediction;
    wire done;

    mnist_top uut (
        .clk(clk), .rst(rst), .start(start), 
        .final_prediction(final_prediction), .done(done)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        start = 0;

        $dumpfile("mnist_signals.vcd");
        $dumpvars(0, mnist_tb);

        $display("Starting Neural Network Inference...");
        $display("--------------------------------------");

        repeat(10) @(posedge clk);
        rst = 0;
        $display("[%0t] TB: Global Reset released.", $time);

        repeat(5) @(posedge clk);
        
        // --- WIDER START PULSE ---
        $display("[%0t] TB: Asserting Start Signal...", $time);
        start = 1;
        @(posedge clk); // Hold for cycle 1
        @(posedge clk); // Hold for cycle 2
        start = 0;
        $display("[%0t] TB: Start Signal Released.", $time);

        fork
            begin
                wait(done);
                $display("--------------------------------------");
                $display("[%0t] TB: SUCCESS - Done signal received!", $time);
                $display("Predicted Digit: %0d", final_prediction[3:0]);
                $display("--------------------------------------");
            end
            
            begin : heartbeat_monitor
                forever begin
                    #1000000; 
                    if (!done)
                        $display("[%0t] TB: Simulation ongoing... (Waiting for Layers)", $time);
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

        #100;
        $finish;
    end
endmodule