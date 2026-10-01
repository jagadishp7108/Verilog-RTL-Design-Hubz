`timescale 1ns/1ps

module i2c_master_tb;
    parameter CLK_DIV = 4;

    reg        clk;
    reg        rst_n;
    reg        start;
    reg  [6:0] addr;
    reg        rw;
    reg  [7:0] data_in;
    wire [7:0] data_out;
    wire       busy;
    wire       ack_error;
    wire       scl;
    wire       sda;

    // Pull-up resistor for I2C open-drain line
    pullup(sda);

    // Instantiate Master
    i2c_master #(.CLK_DIV(CLK_DIV)) uut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .addr(addr),
        .rw(rw),
        .data_in(data_in),
        .data_out(data_out),
        .busy(busy),
        .ack_error(ack_error),
        .scl(scl),
        .sda(sda)
    );

    // 50 MHz Clock
    always #10 clk = ~clk;

    // Emulate Slave ACK directly based on master state
    reg slave_ack;
    assign sda = (slave_ack) ? 1'b0 : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            slave_ack <= 1'b0;
        end else begin
            // Pull SDA low during ACK_ADDR and ACK_DATA states
            if ((uut.state == 3'd3 || (uut.state == 3'd5 && !rw))) begin
                slave_ack <= 1'b1;
            end else begin
                slave_ack <= 1'b0;
            end
        end
    end

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, i2c_master_tb);

        clk     = 0;
        rst_n   = 0;
        start   = 0;
        addr    = 7'h50; // Device Address
        rw      = 0;    // Write
        data_in = 8'hA5;// Data byte 0xA5

        #50;
        rst_n = 1;
        #40;

        // Trigger Byte Write Transaction
        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait until transaction is complete
        @(negedge busy);
        #100;

        $display("[INFO] I2C Master Transaction Finished with ack_error = %b", ack_error);
        $finish;
    end
endmodule
