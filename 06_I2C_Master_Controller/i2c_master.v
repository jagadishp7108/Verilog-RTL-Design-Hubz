`timescale 1ns/1ps

module i2c_master #(
    parameter CLK_DIV = 5 // SCL clock divider
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [6:0] addr,
    input  wire       rw,        // 0: Write, 1: Read
    input  wire [7:0] data_in,
    output reg  [7:0] data_out,
    output reg        busy,
    output reg        ack_error,
    
    // I2C Open-Drain Bus Pins
    output reg        scl,
    inout  wire       sda
);

    localparam IDLE      = 3'd0;
    localparam START     = 3'd1;
    localparam ADDR_RW   = 3'd2;
    localparam ACK_ADDR  = 3'd3;
    localparam DATA      = 3'd4;
    localparam ACK_DATA  = 3'd5;
    localparam STOP      = 3'd6;

    reg [2:0]  state;
    reg [7:0]  clk_cnt;
    reg        scl_clk;
    reg [3:0]  bit_idx;
    reg [7:0]  tx_shift;
    reg [7:0]  rx_shift;
    reg        sda_out;
    reg        sda_oe; // Output enable for open-drain emulation

    // Open-Drain Implementation: drive 0 or high-impedance (Z)
    assign sda = (sda_oe && !sda_out) ? 1'b0 : 1'bz;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clk_cnt <= 0;
            scl_clk <= 1'b0;
        end else if (busy) begin
            if (clk_cnt == CLK_DIV - 1) begin
                clk_cnt <= 0;
                scl_clk <= ~scl_clk;
            end else begin
                clk_cnt <= clk_cnt + 1'b1;
            end
        end else begin
            clk_cnt <= 0;
            scl_clk <= 1'b0;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= IDLE;
            busy      <= 1'b0;
            ack_error <= 1'b0;
            scl       <= 1'b1;
            sda_out   <= 1'b1;
            sda_oe    <= 1'b0;
            bit_idx   <= 0;
            data_out  <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    busy      <= 1'b0;
                    ack_error <= 1'b0;
                    scl       <= 1'b1;
                    sda_out   <= 1'b1;
                    sda_oe    <= 1'b0;
                    if (start) begin
                        busy     <= 1'b1;
                        tx_shift <= {addr, rw};
                        sda_oe   <= 1'b1;
                        sda_out  <= 1'b0; // Generate START Condition (SDA goes low while SCL is high)
                        state    <= START;
                    end
                end

                START: begin
                    if (clk_cnt == CLK_DIV - 1 && scl_clk) begin
                        scl     <= 1'b0;
                        bit_idx <= 4'd7;
                        state   <= ADDR_RW;
                    end
                end

                ADDR_RW: begin
                    sda_oe  <= 1'b1;
                    sda_out <= tx_shift[bit_idx];
                    scl     <= scl_clk;
                    if (clk_cnt == CLK_DIV - 1 && !scl_clk) begin
                        if (bit_idx > 0) begin
                            bit_idx <= bit_idx - 1'b1;
                        end else begin
                            state <= ACK_ADDR;
                        end
                    end
                end

                ACK_ADDR: begin
                    sda_oe <= 1'b0; // Release SDA to read ACK from slave
                    scl    <= scl_clk;
                    if (clk_cnt == CLK_DIV - 1 && scl_clk) begin
                        if (sda !== 1'b0) ack_error <= 1'b1; // Slave must pull low for ACK
                    end else if (clk_cnt == CLK_DIV - 1 && !scl_clk) begin
                        bit_idx  <= 4'd7;
                        tx_shift <= data_in;
                        state    <= DATA;
                    end
                end

                DATA: begin
                    scl <= scl_clk;
                    if (!rw) begin
                        // Master Write
                        sda_oe  <= 1'b1;
                        sda_out <= tx_shift[bit_idx];
                    end else begin
                        // Master Read
                        sda_oe <= 1'b0;
                        if (clk_cnt == CLK_DIV - 1 && scl_clk)
                            rx_shift[bit_idx] <= sda;
                    end

                    if (clk_cnt == CLK_DIV - 1 && !scl_clk) begin
                        if (bit_idx > 0) begin
                            bit_idx <= bit_idx - 1'b1;
                        end else begin
                            state <= ACK_DATA;
                        end
                    end
                end

                ACK_DATA: begin
                    scl <= scl_clk;
                    if (!rw) begin
                        sda_oe <= 1'b0; // Release SDA to check ACK from slave
                        if (clk_cnt == CLK_DIV - 1 && scl_clk) begin
                            if (sda !== 1'b0) ack_error <= 1'b1;
                        end
                    end else begin
                        sda_oe  <= 1'b1;
                        sda_out <= 1'b1; // Send NACK from master on last byte read
                    end

                    if (clk_cnt == CLK_DIV - 1 && !scl_clk) begin
                        state <= STOP;
                    end
                end

                STOP: begin
                    sda_oe  <= 1'b1;
                    sda_out <= 1'b0;
                    if (clk_cnt == CLK_DIV - 1 && scl_clk) begin
                        scl     <= 1'b1;
                    end else if (clk_cnt == CLK_DIV - 1 && !scl_clk) begin
                        sda_out  <= 1'b1; // Generate STOP Condition (SDA goes high while SCL is high)
                        data_out <= rx_shift;
                        state    <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
