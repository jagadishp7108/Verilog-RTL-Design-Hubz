`timescale 1ns/1ps

module dds_sine_gen #(
    parameter ACC_WIDTH   = 16, // Phase accumulator bit-width (N)
    parameter LUT_ADDR_W  = 6,  // 64 sample depth (2^6)
    parameter DATA_WIDTH  = 8   // 8-bit amplitude resolution
)(
    input  wire                   clk,
    input  wire                   rst_n,
    input  wire [ACC_WIDTH-1:0]   tuning_word, // M parameter
    output reg  [DATA_WIDTH-1:0]  sine_out
);

    // Phase Accumulator Register
    reg [ACC_WIDTH-1:0] phase_acc;
    wire [LUT_ADDR_W-1:0] lut_addr;

    // Lookup Table Memory (64 entries of 8-bit unsigned sine samples)
    reg [DATA_WIDTH-1:0] sin_lut [0:(1 << LUT_ADDR_W)-1];

    // Truncate Phase Accumulator to access LUT address
    assign lut_addr = phase_acc[ACC_WIDTH-1 : ACC_WIDTH-LUT_ADDR_W];

    // Initialize 64-point Sine LUT with DC offset (range: 0 to 255, center: 128)
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

    // Phase Accumulator and Synchronous LUT Output
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_acc <= {ACC_WIDTH{1'b0}};
            sine_out  <= 8'd128; // Mid-scale zero point
        end else begin
            phase_acc <= phase_acc + tuning_word;
            sine_out  <= sin_lut[lut_addr];
        end
    end

endmodule
