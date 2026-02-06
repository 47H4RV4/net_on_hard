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

    // 100MHz Clock
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

        repeat(2) @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;
        $display("[%0t] TB: Start Network trigger pulsed.", $time);

        fork
            begin
                wait(done);
                $display("--------------------------------------");
                $display("[%0t] TB: SUCCESS - Done signal received!", $time);
                $display("Predicted Digit: %0d", final_prediction[3:0]);
                $display("--------------------------------------");
            end
            
            // Named block to provide continuous simulation feedback
            begin : heartbeat_monitor
                forever begin
                    #1000000; // Log every 1ms of simulation time
                    if (!done)
                        $display("[%0t] TB: Simulation ongoing... (Waiting for Layers to finish)", $time);
                    else
                        disable heartbeat_monitor;
                end
            end

            begin
                #100000000; // 100ms Timeout
                $display("[%0t] FATAL ERROR: Simulation Timed Out!", $time);
                $finish;
            end
        join_any

        #100;
        $finish;
    end
endmodule