`timescale 1ns/1ps
module spi_master #(
    parameter CLK_DIV = 4 // SCLK frequency = CLK / (2 * CLK_DIV)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       start,
    input  wire [7:0] tx_data,
    output reg  [7:0] rx_data,
    output reg        busy,
    // SPI Bus Lines
    output reg        sclk,
    output reg        mosi,
    input  wire       miso,
    output reg        cs_n
);

    // State definitions
    localparam IDLE     = 2'b00;
    localparam TRANSFER = 2'b01;
    localparam DONE     = 2'b10;

    reg [1:0] state;
    reg [7:0] clk_cnt;
    reg [2:0] bit_cnt;
    reg [7:0] shift_reg_tx;
    reg [7:0] shift_reg_rx;
    reg       sclk_edge;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= IDLE;
            sclk         <= 1'b0; // Mode 0 idle SCLK is LOW
            mosi         <= 1'b0;
            cs_n         <= 1'b1; // Active-low chip select
            busy         <= 1'b0;
            rx_data      <= 8'h00;
            clk_cnt      <= 0;
            bit_cnt      <= 3'd7;
            shift_reg_tx <= 8'h00;
            shift_reg_rx <= 8'h00;
            sclk_edge    <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    cs_n      <= 1'b1;
                    sclk      <= 1'b0;
                    busy      <= 1'b0;
                    clk_cnt   <= 0;
                    sclk_edge <= 1'b0;
                    if (start) begin
                        busy         <= 1'b1;
                        cs_n         <= 1'b0;
                        shift_reg_tx <= tx_data;
                        mosi         <= tx_data[7]; // Setup MSB on MOSI before first edge
                        bit_cnt      <= 3'd7;
                        state        <= TRANSFER;
                    end
                end

                TRANSFER: begin
                    if (clk_cnt < CLK_DIV - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt   <= 0;
                        sclk      <= ~sclk;
                        sclk_edge <= ~sclk_edge;

                        // Rising edge: Sample MISO (Mode 0: sample on rising edge)
                        if (~sclk) begin
                            shift_reg_rx[bit_cnt] <= miso;
                        end
                        // Falling edge: Shift next MOSI bit
                        else begin
                            if (bit_cnt > 0) begin
                                bit_cnt <= bit_cnt - 1'b1;
                                mosi    <= shift_reg_tx[bit_cnt - 1'b1];
                            end else begin
                                state <= DONE;
                            end
                        end
                    end
                end

                DONE: begin
                    sclk    <= 1'b0;
                    cs_n    <= 1'b1;
                    busy    <= 1'b0;
                    rx_data <= shift_reg_rx;
                    state   <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
