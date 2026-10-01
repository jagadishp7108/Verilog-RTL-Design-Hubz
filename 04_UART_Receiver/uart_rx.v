`timescale 1ns/1ps

module uart_rx #(
    parameter CLK_FREQ  = 10000000, // 10 MHz
    parameter BAUD_RATE = 1000000   // 1 MHz (10 clocks per bit)
)(
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx,
    output reg  [7:0] rx_data,
    output reg        rx_done
);

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    localparam IDLE  = 3'b000;
    localparam START = 3'b001;
    localparam DATA  = 3'b010;
    localparam STOP  = 3'b011;

    reg [2:0]  state;
    reg [15:0] clk_count;
    reg [2:0]  bit_index;
    reg [7:0]  rx_data_reg;

    // 2-stage synchronizer
    reg rx_sync1;
    reg rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= IDLE;
            clk_count   <= 0;
            bit_index   <= 0;
            rx_data     <= 8'h00;
            rx_data_reg <= 8'h00;
            rx_done     <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                IDLE: begin
                    clk_count <= 0;
                    bit_index <= 0;
                    if (rx_sync2 == 1'b0) begin
                        state <= START;
                    end
                end

                START: begin
                    if (clk_count == (CLKS_PER_BIT / 2)) begin
                        if (rx_sync2 == 1'b0) begin
                            clk_count <= 0;
                            state     <= DATA;
                        end else begin
                            state <= IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        rx_data_reg[bit_index] <= rx_sync2;
                        if (bit_index < 7) begin
                            bit_index <= bit_index + 1'b1;
                        end else begin
                            bit_index <= 0;
                            state     <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_count < CLKS_PER_BIT - 1) begin
                        clk_count <= clk_count + 1'b1;
                    end else begin
                        clk_count <= 0;
                        rx_done   <= 1'b1;
                        rx_data   <= rx_data_reg;
                        state     <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
