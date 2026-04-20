// xadc_sampler.v
// Corrected INIT registers for VAUX0 single channel continuous mode.
//
// Key fix: INIT_41 bits[4:0] must be 5'b10000 (=16=0x10) to select
// VAUX0 channel. Previous value 0x10C0 had bits[4:0]=0 selecting the
// on-chip temperature sensor instead of the analog input.
//
// INIT_40 = 0x9000:
//   bit[12]   = 1  : disable averaging
//   bit[8]    = 1  : enable VAUX inputs
//   bits[13:12]=00 : single channel mode
//
// INIT_41 = 0x2010:
//   bits[15:12]=0010: continuous sampling mode (was 0001, now 0010=safe)
//   bits[4:0]  =10000: channel select = VAUX0 (address 0x10 = 16)
//
// INIT_48 = 0x0001:
//   bit[0] = 1 : enable VAUX0 in channel sequencer (bit 0, not bit 1)
//   VAUX0 is sequencer bit 0 per UG480 Table 4-5
 
module xadc_sampler (
    input  wire        clk,
    input  wire        rst,
    output reg  [11:0] sample,
    output reg         sample_valid
);
 
    wire [15:0] do_out;
    wire        drdy_out;
    wire        eoc_out;
    wire        eos_out;
    wire        busy_out;
    wire [4:0]  channel_out;
    wire [7:0]  alm_out;
    wire        ot_out;
    wire        jtagbusy_out;
    wire        jtaglocked_out;
    wire        jtagmodified_out;
    wire [4:0]  muxaddr_out;
 
    XADC #(
        // Single channel mode, VAUX inputs enabled
        .INIT_40 (16'h9000),
        // Continuous sampling, channel = VAUX0 (bits[4:0] = 5'b10000 = 0x10)
        .INIT_41 (16'h2010),
        // ADC clock divider = 4 -> 25 MHz ADC clock -> ~960 KSPS
        .INIT_42 (16'h0400),
        .INIT_43 (16'h0000),
        .INIT_44 (16'h0000),
        .INIT_45 (16'h0000),
        .INIT_46 (16'h0000),
        .INIT_47 (16'h0000),
        // Sequencer: enable VAUX0 — bit[0] per UG480 Table 4-5
        .INIT_48 (16'h0001),
        .INIT_49 (16'h0000),
        .INIT_4A (16'h0000),
        .INIT_4B (16'h0000),
        .INIT_4C (16'h0000),
        .INIT_4D (16'h0000),
        .INIT_4E (16'h0000),
        .INIT_4F (16'h0000),
        .INIT_50 (16'hB5ED), .INIT_51 (16'h57E4),
        .INIT_52 (16'hA147), .INIT_53 (16'hCA33),
        .INIT_54 (16'hA93A), .INIT_55 (16'h52C6),
        .INIT_56 (16'h9555), .INIT_57 (16'hAE4E),
        .INIT_58 (16'h5999), .INIT_5C (16'h5111),
        .SIM_MONITOR_FILE ("design.txt")
    ) xadc_inst (
        .DCLK         (clk),
        .RESET        (rst),
        .VAUXP        (16'b0000000000000001),
        .VAUXN        (16'b0000000000000000),
        .VP           (1'b0),
        .VN           (1'b0),
        // Read VAUX0 result register — DRP address 0x10
        .DADDR        (7'h10),
        .DEN          (eoc_out),
        .DWE          (1'b0),
        .DI           (16'h0000),
        .DO           (do_out),
        .DRDY         (drdy_out),
        .CONVST       (1'b0),
        .CONVSTCLK    (1'b0),
        .EOC          (eoc_out),
        .EOS          (eos_out),
        .BUSY         (busy_out),
        .CHANNEL      (channel_out),
        .ALM          (alm_out),
        .OT           (ot_out),
        .JTAGBUSY     (jtagbusy_out),
        .JTAGLOCKED   (jtaglocked_out),
        .JTAGMODIFIED (jtagmodified_out),
        .MUXADDR      (muxaddr_out)
    );
 
    // Latch result — XADC left-aligns in [15:4]
    always @(posedge clk) begin
        if (rst) begin
            sample       <= 12'h000;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
            if (drdy_out) begin
                sample       <= do_out[15:4];
                sample_valid <= 1'b1;
            end
        end
    end
 
endmodule