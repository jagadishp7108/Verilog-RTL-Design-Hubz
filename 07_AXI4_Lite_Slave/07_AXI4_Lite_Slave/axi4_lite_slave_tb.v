`timescale 1ns/1ps

module axi4_lite_slave_tb;
    parameter ADDR_WIDTH = 4;
    parameter DATA_WIDTH = 32;

    reg                    s_axi_aclk;
    reg                    s_axi_aresetn;
    reg  [ADDR_WIDTH-1:0]  s_axi_awaddr;
    reg                    s_axi_awvalid;
    wire                   s_axi_awready;
    reg  [DATA_WIDTH-1:0]  s_axi_wdata;
    reg  [(DATA_WIDTH/8)-1:0] s_axi_wstrb;
    reg                    s_axi_wvalid;
    wire                   s_axi_wready;
    wire [1:0]             s_axi_bresp;
    wire                   s_axi_bvalid;
    reg                    s_axi_bready;
    reg  [ADDR_WIDTH-1:0]  s_axi_araddr;
    reg                    s_axi_arvalid;
    wire                   s_axi_arready;
    wire [DATA_WIDTH-1:0]  s_axi_rdata;
    wire [1:0]             s_axi_rresp;
    wire                   s_axi_rvalid;
    reg                    s_axi_rready;

    // Instantiate AXI-Lite Slave
    axi4_lite_slave #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) uut (
        .s_axi_aclk(s_axi_aclk),
        .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready)
    );

    // 100 MHz Clock
    always #5 s_axi_aclk = ~s_axi_aclk;

    // AXI Write Task
    task axi_write(input [ADDR_WIDTH-1:0] addr, input [DATA_WIDTH-1:0] data);
        begin
            @(posedge s_axi_aclk);
            s_axi_awaddr  <= addr;
            s_axi_awvalid <= 1'b1;
            s_axi_wdata   <= data;
            s_axi_wvalid  <= 1'b1;
            s_axi_wstrb   <= 4'b1111;
            s_axi_bready  <= 1'b1;

            @(posedge s_axi_aclk);
            while (!s_axi_awready || !s_axi_wready) @(posedge s_axi_aclk);
            
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;

            while (!s_axi_bvalid) @(posedge s_axi_aclk);
            @(posedge s_axi_aclk);
            s_axi_bready  <= 1'b0;
        end
    endtask

    // AXI Read Task
    task axi_read(input [ADDR_WIDTH-1:0] addr);
        begin
            @(posedge s_axi_aclk);
            s_axi_araddr  <= addr;
            s_axi_arvalid <= 1'b1;
            s_axi_rready  <= 1'b1;

            @(posedge s_axi_aclk);
            while (!s_axi_arready) @(posedge s_axi_aclk);
            s_axi_arvalid <= 1'b0;

            while (!s_axi_rvalid) @(posedge s_axi_aclk);
            @(posedge s_axi_aclk);
            s_axi_rready  <= 1'b0;
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, axi4_lite_slave_tb);

        s_axi_aclk    = 0;
        s_axi_aresetn = 0;
        s_axi_awvalid = 0;
        s_axi_wvalid  = 0;
        s_axi_bready  = 0;
        s_axi_arvalid = 0;
        s_axi_rready  = 0;

        #25;
        s_axi_aresetn = 1;
        #20;

        // Write 0xDEADBEEF into Register 0 (Offset 0x0)
        axi_write(4'h0, 32'hDEADBEEF);
        #30;

        // Write 0x12345678 into Register 1 (Offset 0x4)
        axi_write(4'h4, 32'h12345678);
        #30;

        // Read back from Register 0
        axi_read(4'h0);
        #30;

        // Read back from Register 1
        axi_read(4'h4);
        #50;

        $display("[INFO] AXI4-Lite Slave Simulation Finished Successfully!");
        $finish;
    end
endmodule
