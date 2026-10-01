`timescale 1ns/1ps

module fifo_tb;
    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;

    reg clk;
    reg rst_n;
    reg wr_en;
    reg rd_en;
    reg [DATA_WIDTH-1:0] wr_data;
    wire [DATA_WIDTH-1:0] rd_data;
    wire full;
    wire empty;

    // Instantiate FIFO
    sync_fifo #(DATA_WIDTH, ADDR_WIDTH) uut (
        .clk(clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .rd_en(rd_en),
        .wr_data(wr_data),
        .rd_data(rd_data),
        .full(full),
        .empty(empty)
    );

    // Clock Generation (10ns period -> 100MHz)
    always #5 clk = ~clk;

    initial begin
        // Setup waveform dump for EPWave
        $dumpfile("dump.vcd");
        $dumpvars(0, fifo_tb);

        // Init signals
        clk = 0;
        rst_n = 0;
        wr_en = 0;
        rd_en = 0;
        wr_data = 8'h00;

        // Apply Reset
        #20;
        rst_n = 1;
        #10;

        // 1. Write until FULL
        $display("[INFO] Writing to FIFO...");
        repeat (16) begin
            @(posedge clk);
            if (!full) begin
                wr_en = 1;
                wr_data = $random;
            end
        end
        @(posedge clk);
        wr_en = 0;

        // 2. Read until EMPTY
        #20;
        $display("[INFO] Reading from FIFO...");
        repeat (16) begin
            @(posedge clk);
            if (!empty) begin
                rd_en = 1;
            end
        end
        @(posedge clk);
        rd_en = 0;

        #40;
        $display("[INFO] Simulation Complete.");
        $finish;
    end
endmodule
