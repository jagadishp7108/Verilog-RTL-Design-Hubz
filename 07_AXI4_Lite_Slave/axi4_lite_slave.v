`timescale 1ns/1ps

module axi4_lite_slave #(
    parameter ADDR_WIDTH = 4,
    parameter DATA_WIDTH = 32
)(
    input  wire                    s_axi_aclk,
    input  wire                    s_axi_aresetn,

    // Write Address Channel (AW)
    input  wire [ADDR_WIDTH-1:0]   s_axi_awaddr,
    input  wire                    s_axi_awvalid,
    output reg                     s_axi_awready,

    // Write Data Channel (W)
    input  wire [DATA_WIDTH-1:0]   s_axi_wdata,
    input  wire [(DATA_WIDTH/8)-1:0] s_axi_wstrb,
    input  wire                    s_axi_wvalid,
    output reg                     s_axi_wready,

    // Write Response Channel (B)
    output reg  [1:0]              s_axi_bresp,
    output reg                     s_axi_bvalid,
    input  wire                    s_axi_bready,

    // Read Address Channel (AR)
    input  wire [ADDR_WIDTH-1:0]   s_axi_araddr,
    input  wire                    s_axi_arvalid,
    output reg                     s_axi_arready,

    // Read Data Channel (R)
    output reg  [DATA_WIDTH-1:0]   s_axi_rdata,
    output reg  [1:0]              s_axi_rresp,
    output reg                     s_axi_rvalid,
    input  wire                    s_axi_rready
);

    // 4 Internal Memory Mapped Registers
    reg [DATA_WIDTH-1:0] slv_reg0;
    reg [DATA_WIDTH-1:0] slv_reg1;
    reg [DATA_WIDTH-1:0] slv_reg2;
    reg [DATA_WIDTH-1:0] slv_reg3;

    reg [ADDR_WIDTH-1:0] axi_awaddr;
    reg [ADDR_WIDTH-1:0] axi_araddr;

    // Write Handshake Logic
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 1'b0;
            s_axi_wready  <= 1'b0;
            s_axi_bvalid  <= 1'b0;
            s_axi_bresp   <= 2'b00; // OKAY
            slv_reg0      <= 32'd0;
            slv_reg1      <= 32'd0;
            slv_reg2      <= 32'd0;
            slv_reg3      <= 32'd0;
        end else begin
            // Address & Data Ready Assertion
            if (!s_axi_awready && s_axi_awvalid && s_axi_wvalid) begin
                s_axi_awready <= 1'b1;
                s_axi_wready  <= 1'b1;
                axi_awaddr    <= s_axi_awaddr;
            end else begin
                s_axi_awready <= 1'b0;
                s_axi_wready  <= 1'b0;
            end

            // Write to Register
            if (s_axi_awready && s_axi_wready) begin
                case (axi_awaddr[3:2])
                    2'b00: slv_reg0 <= s_axi_wdata;
                    2'b01: slv_reg1 <= s_axi_wdata;
                    2'b10: slv_reg2 <= s_axi_wdata;
                    2'b11: slv_reg3 <= s_axi_wdata;
                endcase
                s_axi_bvalid <= 1'b1;
            end

            if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end
        end
    end

    // Read Handshake Logic
    always @(posedge s_axi_aclk or negedge s_axi_aresetn) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 1'b0;
            s_axi_rvalid  <= 1'b0;
            s_axi_rresp   <= 2'b00; // OKAY
            s_axi_rdata   <= 32'd0;
        end else begin
            if (!s_axi_arready && s_axi_arvalid) begin
                s_axi_arready <= 1'b1;
                axi_araddr    <= s_axi_araddr;
            end else begin
                s_axi_arready <= 1'b0;
            end

            if (s_axi_arready) begin
                s_axi_rvalid <= 1'b1;
                case (axi_araddr[3:2])
                    2'b00: s_axi_rdata <= slv_reg0;
                    2'b01: s_axi_rdata <= slv_reg1;
                    2'b10: s_axi_rdata <= slv_reg2;
                    2'b11: s_axi_rdata <= slv_reg3;
                endcase
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end

endmodule
