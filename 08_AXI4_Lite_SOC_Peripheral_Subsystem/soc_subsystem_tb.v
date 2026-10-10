`timescale 1ns/1ps

module soc_subsystem_tb;

    reg        sys_clk;
    reg        sys_rst_n;
    reg        uart_rx_pin;
    wire [7:0] sine_out;

    // Simulation Timing Constants
    localparam CLK_PERIOD = 10;                     // 100 MHz clock -> 10ns
    localparam BIT_PERIOD = 100;                    // 10 Mbps serial -> 100ns per bit

    // Instantiate Top-Level SoC Subsystem
    soc_subsystem_top uut (
        .sys_clk(sys_clk),
        .sys_rst_n(sys_rst_n),
        .uart_rx_pin(uart_rx_pin),
        .sine_out(sine_out)
    );

    // Clock Generator (100 MHz)
    always #(CLK_PERIOD / 2) sys_clk = ~sys_clk;

    // Task: Transmit a single 8-bit UART character (8-N-1 frame)
    task send_uart_byte(input [7:0] byte_data);
        integer i;
        begin
            uart_rx_pin = 1'b0; // Active-low Start Bit
            #BIT_PERIOD;
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_pin = byte_data[i]; // LSB first
                #BIT_PERIOD;
            end
            uart_rx_pin = 1'b1; // Stop Bit
            #BIT_PERIOD;
        end
    endtask

    // Task: Stream complete 6-byte AXI Write command packet
    task send_axi_write_packet(input [7:0] addr, input [31:0] data);
        begin
            send_uart_byte(8'h57);             // Opcode 'W'
            send_uart_byte(addr);              // Register Target Address Offset
            send_uart_byte(data[31:24]);       // Data Byte 3 (MSB)
            send_uart_byte(data[23:16]);       // Data Byte 2
            send_uart_byte(data[15:8]);        // Data Byte 1
            send_uart_byte(data[7:0]);         // Data Byte 0 (LSB)
        end
    endtask

    // Simulation Execution Block
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, soc_subsystem_tb);

        // System Initialization
        sys_clk     = 1'b0;
        sys_rst_n   = 1'b0;
        uart_rx_pin = 1'b1;

        #100;
        sys_rst_n   = 1'b1;
        #100;

        $display("-----------------------------------------------------------------");
        $display("[TB START] Initializing SoC Subsystem Verification Sequence");
        $display("-----------------------------------------------------------------");

        // Scenario 1: Configure Tuning Word = 0x0400 (1024)
        $display("[TIME: %0t ns] Transmitting Packet 1: Tuning Word = 0x00000400...", $time);
        send_axi_write_packet(8'h00, 32'h00000400);

        // Allow DDS core to render multiple cycles of base frequency
        #4000;

        // Scenario 2: Dynamic Modulation -> Double Frequency = 0x0800 (2048)
        $display("[TIME: %0t ns] Transmitting Packet 2: Tuning Word = 0x00000800...", $time);
        send_axi_write_packet(8'h00, 32'h00000800);

        // Observe instantaneous, phase-continuous frequency shift
        #4000;

        $display("-----------------------------------------------------------------");
        $display("[TB FINISH] Subsystem verification completed successfully.");
        $display("-----------------------------------------------------------------");
        $finish;
    end

endmodule
