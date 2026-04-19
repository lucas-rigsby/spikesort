// xadc_sampler.v
// Artix-7 XADC — single channel continuous mode on VAUXP[0]/VAUXN[0].
// Physical pins: J3 (VP, signal) and K3 (VN, GND ref) on JXADC header.
//
// No XDC constraints are needed for J3/K3.  The XADC analog inputs are
// dedicated pads resolved automatically by Vivado from the primitive
// instantiation.  Adding PACKAGE_PIN or IOSTANDARD constraints for these
// pins causes [Common 17-69] and [Constraints 18-1063] errors.
//
// sample_valid is a ONE-CYCLE pulse at 100 MHz (~960 KSPS).
// The spike_detector runs at 1 MHz — see spike_sorter_top.v for the
// stretch logic that makes this pulse visible across the clock boundary.

module xadc_sampler (
    input  wire        clk,           // 100 MHz system clock
    input  wire        rst,
    output reg  [11:0] sample,        // 12-bit result: 0x000=0V, 0xFFF=1V
    output reg         sample_valid   // one-cycle strobe at 100 MHz
);

    wire [15:0] do_out;
    wire        drdy_out;
    wire        eoc_out;

    // All output ports declared to suppress [Synth 8-7071] warnings
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
        // INIT_40: single channel mode, auxiliary inputs enabled
        .INIT_40 (16'h9000),
        // INIT_41: continuous sampling, channel address 0x10 = VAUX0
        .INIT_41 (16'h10C0),
        // INIT_42: ADC clock divider = 4 -> f_ADC = 25 MHz -> ~960 KSPS
        .INIT_42 (16'h0400),
        .INIT_43 (16'h0000),
        .INIT_44 (16'h0000),
        .INIT_45 (16'h0000),
        .INIT_46 (16'h0000),
        .INIT_47 (16'h0000),
        // INIT_48: sequencer channel enable, bit[1] = VAUX0
        .INIT_48 (16'h0002),
        .INIT_49 (16'h0000),
        .INIT_4A (16'h0000),
        .INIT_4B (16'h0000),
        .INIT_4C (16'h0000),
        .INIT_4D (16'h0000),
        .INIT_4E (16'h0000),
        .INIT_4F (16'h0000),
        // Alarm thresholds — Xilinx defaults, not used
        .INIT_50 (16'hB5ED), .INIT_51 (16'h57E4),
        .INIT_52 (16'hA147), .INIT_53 (16'hCA33),
        .INIT_54 (16'hA93A), .INIT_55 (16'h52C6),
        .INIT_56 (16'h9555), .INIT_57 (16'hAE4E),
        .INIT_58 (16'h5999), .INIT_5C (16'h5111),
        .SIM_MONITOR_FILE ("design.txt")
    ) xadc_inst (
        .DCLK         (clk),
        .RESET        (rst),
        // Analog inputs — dedicated pads, no XDC entry needed
        .VAUXP        (16'b0000000000000001),
        .VAUXN        (16'b0000000000000000),
        .VP           (1'b0),
        .VN           (1'b0),
        // DRP interface — read result on every EOC pulse
        .DADDR        (7'h10),
        .DEN          (eoc_out),
        .DWE          (1'b0),
        .DI           (16'h0000),
        .DO           (do_out),
        .DRDY         (drdy_out),
        // Conversion control — not used in continuous mode
        .CONVST       (1'b0),
        .CONVSTCLK    (1'b0),
        // Status outputs — all connected to suppress unconnected warnings
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

    // Latch 12-bit result — XADC left-aligns result in [15:4]
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
