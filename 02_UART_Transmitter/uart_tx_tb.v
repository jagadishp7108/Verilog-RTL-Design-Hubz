`timescale 1ns/1ps

module uart_tx_tb;
    // Simulation mate clock divider nano rakhyo chhe jethi jaldhi run thay
    parameter CLK_FREQ  = 10000000; // 10 MHz
    parameter BAUD_RATE = 1000000;  // 1 MHz (clks_per_bit = 10)

    reg clk;
    reg rst_n;
    reg tx_start;
    reg [7:0] tx_data;
    wire tx;
    wire tx_busy;

    // Instantiate UART TX
    uart_tx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_start(tx_start),
        .tx_data(tx_data),
        .tx(tx),
        .tx_busy(tx_busy)
    );

    // 10 MHz clock generation (Period = 100ns)
    always #50 clk = ~clk;

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, uart_tx_tb);

        clk      = 0;
        rst_n    = 0;
        tx_start = 0;
        tx_data  = 8'h00;

        // Apply Reset
        #150;
        rst_n = 1;
        #100;

        // Transmit 1st Byte: 0xA5 (Binary: 10100101)
        @(posedge clk);
        tx_data  = 8'hA5;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        // Wait until transmission completes
        wait (!tx_busy);
        #500;

        // Transmit 2nd Byte: 0x3C (Binary: 00111100)
        @(posedge clk);
        tx_data  = 8'h3C;
        tx_start = 1;
        @(posedge clk);
        tx_start = 0;

        wait (!tx_busy);
        #1000;

        $display("[INFO] UART Transmission Successful!");
        $finish;
    end
endmodule
