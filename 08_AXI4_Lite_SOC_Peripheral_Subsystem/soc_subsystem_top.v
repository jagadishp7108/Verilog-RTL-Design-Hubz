`timescale 1ns/1ps

// =============================================================================
// Module: soc_subsystem_top
// Description: Top-Level SoC Subsystem bridging UART packets to an AMBA
//              AXI4-Lite interconnect to drive a DDS/NCO waveform generator.
// Standards: Synthesizable Verilog-2001, CDC-hardened, AMBA AXI4-Lite Compliant.
// =============================================================================

module soc_subsystem_top (
    input  wire        sys_clk,
    input  wire        sys_rst_n,
    input  wire        uart_rx_pin,
    output wire [7:0]  sine_out
);

    // Internal Bus & Handshake Wires
    wire [7:0]  rx_byte;
    wire        rx_done;

    wire [7:0]  m_awaddr;
    wire        m_awvalid;
    wire        m_awready;

    wire [31:0] m_wdata;
    wire [3:0]  m_wstrb;
    wire        m_wvalid;
    wire        m_wready;

    wire [1:0]  m_bresp;
    wire        m_bvalid;
    wire        m_bready;

    // -------------------------------------------------------------------------
    // Sub-module 1: UART Receiver Core with 2-Stage CDC Synchronizer
    // -------------------------------------------------------------------------
    uart_rx #(
        .CLK_FREQ(100_000_000),
        .BAUD_RATE(10_000_000) // Fast baud rate for quick simulation
    ) u_rx (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .rx(uart_rx_pin),
        .rx_data(rx_byte),
        .rx_done(rx_done)
    );

    // -------------------------------------------------------------------------
    // Sub-module 2: Command Protocol to AXI4-Lite Master Bridge
    // -------------------------------------------------------------------------
    uart_to_axi_bridge #(
        .ADDR_WIDTH(8),
        .DATA_WIDTH(32)
    ) u_bridge (
        .clk(sys_clk),
        .rst_n(sys_rst_n),
        .rx_byte(rx_byte),
        .rx_done(rx_done),
        .m_axi_awaddr(m_awaddr),
        .m_axi_awvalid(m_awvalid),
        .m_axi_awready(m_awready),
        .m_axi_wdata(m_wdata),
        .m_axi_wstrb(m_wstrb),
        .m_axi_wvalid(m_wvalid),
        .m_axi_wready(m_wready),
        .m_axi_bresp(m_bresp),
        .m_axi_bvalid(m_bvalid),
        .m_axi_bready(m_bready)
    );

    // -------------------------------------------------------------------------
    // Sub-module 3: AXI4-Lite Memory-Mapped DDS Peripheral
    // -------------------------------------------------------------------------
    axi_dds_peripheral #(
        .DATA_WIDTH(32)
    ) u_axi_dds (
        .s_axi_aclk(sys_clk),
        .s_axi_aresetn(sys_rst_n),
        .s_axi_awaddr(m_awaddr[3:0]),
        .s_axi_awvalid(m_awvalid),
        .s_axi_awready(m_awready),
        .s_axi_wdata(m_wdata),
        .s_axi_wvalid(m_wvalid),
        .s_axi_wready(m_wready),
        .s_axi_bresp(m_bresp),
        .s_axi_bvalid(m_bvalid),
        .s_axi_bready(m_bready),
        .analog_sine_wave(sine_out)
    );

endmodule


// =============================================================================
// Implementation: UART Receiver Core (CDC-hardened + Mid-bit Sampling)
// =============================================================================
module uart_rx #(
    parameter CLK_FREQ  = 100_000_000,
    parameter BAUD_RATE = 10_000_000
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
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shifter;
    reg        rx_sync1, rx_sync;

    // 2-Stage Flip-Flop Synchronizer for Metastability Hardening (CDC)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync  <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync  <= rx_sync1;
        end
    end

    // Deserializer FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            clk_cnt    <= 16'd0;
            bit_idx    <= 3'd0;
            rx_data    <= 8'd0;
            rx_done    <= 1'b0;
            rx_shifter <= 8'd0;
        end else begin
            rx_done <= 1'b0;
            case (state)
                IDLE: begin
                    clk_cnt <= 16'd0;
                    bit_idx <= 3'd0;
                    if (rx_sync == 1'b0) state <= START;
                end

                START: begin
                    if (clk_cnt == (CLKS_PER_BIT / 2)) begin
                        if (rx_sync == 1'b0) begin
                            clk_cnt <= 16'd0;
                            state   <= DATA;
                        end else begin
                            state <= IDLE; // False glitch rejection
                        end
                    end else begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end
                end

                DATA: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        clk_cnt              <= 16'd0;
                        rx_shifter[bit_idx]  <= rx_sync;
                        if (bit_idx < 3'd7) begin
                            bit_idx <= bit_idx + 1'b1;
                        end else begin
                            state <= STOP;
                        end
                    end
                end

                STOP: begin
                    if (clk_cnt < CLKS_PER_BIT - 1) begin
                        clk_cnt <= clk_cnt + 1'b1;
                    end else begin
                        rx_done <= 1'b1;
                        rx_data <= rx_shifter;
                        state   <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule


// =============================================================================
// Implementation: Protocol Bridge (UART 6-Byte Packet -> AXI4-Lite Master)
// =============================================================================
module uart_to_axi_bridge #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [7:0]             rx_byte,
    input  wire                   rx_done,

    output reg  [ADDR_WIDTH-1:0]  m_axi_awaddr,
    output reg                    m_axi_awvalid,
    input  wire                   m_axi_awready,

    output reg  [DATA_WIDTH-1:0]  m_axi_wdata,
    output reg  [3:0]             m_axi_wstrb,
    output reg                    m_axi_wvalid,
    input  wire                   m_axi_wready,

    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output reg                    m_axi_bready
);
    localparam S_IDLE      = 3'd0;
    localparam S_RX_ADDR   = 3'd1;
    localparam S_RX_DATA0  = 3'd2;
    localparam S_RX_DATA1  = 3'd3;
    localparam S_RX_DATA2  = 3'd4;
    localparam S_RX_DATA3  = 3'd5;
    localparam S_AXI_WRITE = 3'd6;
    localparam S_AXI_WRESP = 3'd7;

    reg [2:0] state;
    reg [DATA_WIDTH-1:0] data_shifter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            data_shifter  <= 32'h0;
            m_axi_awaddr  <= {ADDR_WIDTH{1'b0}};
            m_axi_awvalid <= 1'b0;
            m_axi_wdata   <= {DATA_WIDTH{1'b0}};
            m_axi_wstrb   <= 4'b1111;
            m_axi_wvalid  <= 1'b0;
            m_axi_bready  <= 1'b0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (rx_done && (rx_byte == 8'h57)) begin // 'W' Opcode
                        state <= S_RX_ADDR;
                    end
                end

                S_RX_ADDR: begin
                    if (rx_done) begin
                        m_axi_awaddr <= rx_byte;
                        state        <= S_RX_DATA0;
                    end
                end

                S_RX_DATA0: begin
                    if (rx_done) begin
                        data_shifter[31:24] <= rx_byte;
                        state <= S_RX_DATA1;
                    end
                end

                S_RX_DATA1: begin
                    if (rx_done) begin
                        data_shifter[23:16] <= rx_byte;
                        state <= S_RX_DATA2;
                    end
                end

                S_RX_DATA2: begin
                    if (rx_done) begin
                        data_shifter[15:8] <= rx_byte;
                        state <= S_RX_DATA3;
                    end
                end

                S_RX_DATA3: begin
                    if (rx_done) begin
                        data_shifter[7:0] <= rx_byte;
                        m_axi_wdata       <= {data_shifter[31:8], rx_byte};
                        m_axi_awvalid     <= 1'b1;
                        m_axi_wvalid      <= 1'b1;
                        state             <= S_AXI_WRITE;
                    end
                end

                S_AXI_WRITE: begin
                    // Clear VALID signals independently upon READY acknowledgment
                    if (m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wready)  m_axi_wvalid  <= 1'b0;

                    if ((m_axi_awready || !m_axi_awvalid) && (m_axi_wready || !m_axi_wvalid)) begin
                        m_axi_bready <= 1'b1;
                        state        <= S_AXI_WRESP;
                    end
                end

                S_AXI_WRESP: begin
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        state        <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule


// =============================================================================
// Implementation: AXI4-Lite DDS Peripheral (Register Address 0x0)
// =============================================================================
module axi_dds_peripheral #(
    parameter DATA_WIDTH = 32
)(
    input  wire                  s_axi_aclk,
    input  wire                  s_axi_aresetn,
    input  wire [3:0]            s_axi_awaddr,
    input  wire                  s_axi_awvalid,
    output reg                   s_axi_awready,
    input  wire [DATA_WIDTH-1:0] s_axi_wdata,
    input  wire                  s_axi_wvalid,
    output reg                   s_axi_wready,
    output reg  [1:0]            s_axi_bresp,
    output reg                   s_axi_bvalid,
    input  wire                  s_axi_bready,

    output wire [7:0]            analog_sine_wave
);
    reg [15:0] freq_tuning_reg;

    dds_sine_gen #(
        .ACC_WIDTH(16),
        .LUT_ADDR_W(6),
        .DATA_WIDTH(8)
    ) dds_inst (
        .clk(s_axi_aclk),
        .rst_n(s_axi_aresetn),
        .tuning_word(freq_tuning_reg),
        .sine_out(analog_sine_wave)
    );

    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready   <= 1'b0;
            s_axi_wready    <= 1'b0;
            s_axi_bvalid    <= 1'b0;
            s_axi_bresp     <= 2'b00;
            freq_tuning_reg <= 16'd0;
        end else begin
            // Handshake initiation
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            // Latch data into frequency tuning word register
            if (s_axi_awready && s_axi_wready) begin
                freq_tuning_reg <= s_axi_wdata[15:0];
                s_axi_bvalid    <= 1'b1;
                s_axi_bresp     <= 2'b00; // OKAY
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end
endmodule


// =============================================================================
// Implementation: DDS Engine (Phase Accumulator + 64-entry Sine LUT)
// =============================================================================
module dds_sine_gen #(
    parameter ACC_WIDTH   = 16,
    parameter LUT_ADDR_W  = 6,
    parameter DATA_WIDTH  = 8
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [ACC_WIDTH-1:0]   tuning_word,
    output reg  [DATA_WIDTH-1:0]  sine_out
);
    reg [ACC_WIDTH-1:0]   phase_acc;
    wire [LUT_ADDR_W-1:0] lut_addr;
    reg [DATA_WIDTH-1:0]  sin_lut [0:(1 << LUT_ADDR_W)-1];

    assign lut_addr = phase_acc[ACC_WIDTH-1 : ACC_WIDTH-LUT_ADDR_W];

    initial begin
        sin_lut[0]  = 8'd128; sin_lut[1]  = 8'd140; sin_lut[2]  = 8'd152; sin_lut[3]  = 8'd165;
        sin_lut[4]  = 8'd176; sin_lut[5]  = 8'd188; sin_lut[6]  = 8'd198; sin_lut[7]  = 8'd208;
        sin_lut[8]  = 8'd218; sin_lut[9]  = 8'd226; sin_lut[10] = 8'd234; sin_lut[11] = 8'd240;
        sin_lut[12] = 8'd245; sin_lut[13] = 8'd250; sin_lut[14] = 8'd253; sin_lut[15] = 8'd254;
        sin_lut[16] = 8'd255; sin_lut[17] = 8'd254; sin_lut[18] = 8'd253; sin_lut[19] = 8'd250;
        sin_lut[20] = 8'd245; sin_lut[21] = 8'd240; sin_lut[22] = 8'd234; sin_lut[23] = 8'd226;
        sin_lut[24] = 8'd218; sin_lut[25] = 8'd208; sin_lut[26] = 8'd198; sin_lut[27] = 8'd188;
        sin_lut[28] = 8'd176; sin_lut[29] = 8'd165; sin_lut[30] = 8'd152; sin_lut[31] = 8'd140;
        sin_lut[32] = 8'd128; sin_lut[33] = 8'd115; sin_lut[34] = 8'd103; sin_lut[35] = 8'd90;
        sin_lut[36] = 8'd79;  sin_lut[37] = 8'd67;  sin_lut[38] = 8'd57;  sin_lut[39] = 8'd47;
        sin_lut[40] = 8'd37;  sin_lut[41] = 8'd29;  sin_lut[42] = 8'd21;  sin_lut[43] = 8'd15;
        sin_lut[44] = 8'd10;  sin_lut[45] = 8'd5;   sin_lut[46] = 8'd2;   sin_lut[47] = 8'd1;
        sin_lut[48] = 8'd0;   sin_lut[49] = 8'd1;   sin_lut[50] = 8'd2;   sin_lut[51] = 8'd5;
        sin_lut[52] = 8'd10;  sin_lut[53] = 8'd15;  sin_lut[54] = 8'd21;  sin_lut[55] = 8'd29;
        sin_lut[56] = 8'd37;  sin_lut[57] = 8'd47;  sin_lut[58] = 8'd57;  sin_lut[59] = 8'd67;
        sin_lut[60] = 8'd79;  sin_lut[61] = 8'd90;  sin_lut[62] = 8'd103; sin_lut[63] = 8'd115;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= {ACC_WIDTH{1'b0}};
            sine_out  <= 8'd128;
        end else begin
            phase_acc <= phase_acc + tuning_word;
            sine_out  <= sin_lut[lut_addr];
        end
    end
endmodule
