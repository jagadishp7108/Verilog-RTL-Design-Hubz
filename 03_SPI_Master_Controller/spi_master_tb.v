`timescale 1ns/1ps

module spi_master_tb;
    parameter CLK_DIV = 2;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [7:0] tx_data;
    wire [7:0] rx_data;
    wire       busy;
    wire       sclk;
    wire       mosi;
    reg        miso;
    wire       cs_n;

    // Instantiate SPI Master
    spi_master #(
        .CLK_DIV(CLK_DIV)
    ) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .sclk(sclk),
        .mosi(mosi),
        .miso(miso),
        .cs_n(cs_n)
    );

    // 50 MHz Clock generation (20ns period)
    always #10 clk = ~clk;

    // Dummy Slave: Invert MOSI to test full-duplex reception
    always @(negedge sclk or posedge cs_n) begin
        if (cs_n) begin
            miso <= 1'b0;
        end else begin
            miso <= ~mosi;
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, spi_master_tb);

        clk     = 0;
        rst_n   = 0;
        start   = 0;
        tx_data = 8'h00;
        miso    = 0;

        // Apply Reset
        #50;
        rst_n = 1;
        #40;

        // Transaction 1: Send 0xC5
        @(posedge clk);
        tx_data = 8'hC5;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        // Wait fixed time for SPI frame to complete
        #800;

        // Transaction 2: Send 0x5A
        @(posedge clk);
        tx_data = 8'h5A;
        start   = 1'b1;
        @(posedge clk);
        start   = 1'b0;

        #800;

        $display("[INFO] SPI Master Simulation Finished Successfully!");
        $finish;
    end
endmodule
