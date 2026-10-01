`timescale 1ns/1ps

module uart_rx_tb;
    parameter CLK_FREQ  = 10000000; // 10 MHz (Period = 100ns)
    parameter BAUD_RATE = 1000000;  // 1 MHz (Bit period = 1000ns)
    localparam BIT_PERIOD = 1000;   // 1000 ns per bit

    reg        clk;
    reg        rst_n;
    reg        rx;
    wire [7:0] rx_data;
    wire       rx_done;

    // Instantiate ONLY uart_rx
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .rx_data(rx_data),
        .rx_done(rx_done)
    );

    // 10 MHz Clock (100ns period)
    always #50 clk = ~clk;

    // Task to send 1 byte serially down the rx pin
    task send_byte(input [7:0] data);
        integer i;
        begin
            // Start bit (0)
            rx = 1'b0;
            #BIT_PERIOD;

            // 8 Data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #BIT_PERIOD;
            end

            // Stop bit (1)
            rx = 1'b1;
            #BIT_PERIOD;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, uart_rx_tb);

        clk   = 0;
        rst_n = 0;
        rx    = 1'b1; // Idle line is HIGH

        #150;
        rst_n = 1;
        #200;

        // Send Byte 0xA5 serially into RX
        send_byte(8'hA5);
        #500;

        // Send Byte 0x3C serially into RX
        send_byte(8'h3C);
        #1000;

        $display("[INFO] Standalone UART RX Test Complete!");
        $finish;
    end
endmodule
