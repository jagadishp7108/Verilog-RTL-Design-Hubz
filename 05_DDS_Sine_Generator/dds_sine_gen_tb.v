`timescale 1ns/1ps

module dds_sine_gen_tb;
    parameter ACC_WIDTH   = 16;
    parameter LUT_ADDR_W  = 6;
    parameter DATA_WIDTH  = 8;

    reg                   clk;
    reg                   rst_n;
    reg  [ACC_WIDTH-1:0]  tuning_word;
    wire [DATA_WIDTH-1:0] sine_out;

    // Instantiate DDS module
    dds_sine_gen #(
        .ACC_WIDTH(ACC_WIDTH),
        .LUT_ADDR_W(LUT_ADDR_W),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .tuning_word(tuning_word),
        .sine_out(sine_out)
    );

    // 100 MHz System Clock (Period = 10ns)
    always #5 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, dds_sine_gen_tb);

        clk         = 0;
        rst_n       = 0;
        tuning_word = 16'd0;

        // Reset Sequence
        #25;
        rst_n = 1;
        #20;

        // Frequency 1: Set M = 1024 (Step rate)
        @(posedge clk);
        tuning_word = 16'd1024;
        #3000;

        // Dynamic Frequency Switching: Double the frequency (M = 2048)
        @(posedge clk);
        tuning_word = 16'd2048;
        #3000;

        $display("[INFO] DDS Sine Wave Generation Complete!");
        $finish;
    end
endmodule
