// xadc_sampler.v
// ──────────────────────────────────────────────────────────────────────────────
// Instantiates the Artix-7 XADC primitive for single-channel continuous
// sampling on VAUXP[0]/VAUXN[0] — physically connected to JXADC pins J3/K3
// on the Basys-3 board.
//
// IMPORTANT: The VAUXP[0]/VAUXN[0] analog inputs are dedicated XADC pins.
// They do NOT appear as top-level Verilog ports and are NOT constrained in
// the XDC file. Vivado resolves them automatically from the primitive
// instantiation. Attempting to add PACKAGE_PIN or IOSTANDARD constraints
// for J3/K3 in the XDC causes errors [Common 17-69] and [Constraints 18-1063].
//
// Physical connections on the breadboard:
//   J3 (VAUXP[0]) = VP  — analog signal input, 0-1V unipolar
//   K3 (VAUXN[0]) = VN  — reference, connect to GND
//   External filter: 100 ohm series resistor + 10nF differential cap
//
// Configuration:
//   Mode:        Single channel, continuous
//   Channel:     VAUX0 (DRP address 0x10)
//   ADC clock:   100 MHz / 4 = 25 MHz  -> ~960 KSPS
//   Resolution:  12-bit, unipolar 0-1V

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

    XADC #(
        // Configuration Register 0
        // [13:12]=00 single channel, [8]=1 auxiliary input enable
        .INIT_40 (16'h9000),

        // Configuration Register 1
        // [15:12]=0001 continuous, [5:0]=010000 channel addr 0x10 = VAUX0
        .INIT_41 (16'h10C0),

        // Configuration Register 2
        // [15:8]=0x04 ADC clock divider = 4 -> 25 MHz ADC clock -> ~960 KSPS
        .INIT_42 (16'h0400),

        .INIT_43 (16'h0000),
        .INIT_44 (16'h0000),
        .INIT_45 (16'h0000),
        .INIT_46 (16'h0000),
        .INIT_47 (16'h0000),

        // Sequencer channel enable: bit[1]=1 enables VAUX0
        .INIT_48 (16'h0002),
        .INIT_49 (16'h0000),
        .INIT_4A (16'h0000),
        .INIT_4B (16'h0000),
        .INIT_4C (16'h0000),
        .INIT_4D (16'h0000),
        .INIT_4E (16'h0000),
        .INIT_4F (16'h0000),

        // Alarm thresholds (Xilinx defaults, alarms not used)
        .INIT_50 (16'hB5ED),
        .INIT_51 (16'h57E4),
        .INIT_52 (16'hA147),
        .INIT_53 (16'hCA33),
        .INIT_54 (16'hA93A),
        .INIT_55 (16'h52C6),
        .INIT_56 (16'h9555),
        .INIT_57 (16'hAE4E),
        .INIT_58 (16'h5999),
        .INIT_5C (16'h5111),

        .SIM_MONITOR_FILE ("design.txt")
    ) xadc_inst (
        .DCLK      (clk),
        .RESET     (rst),

        // Analog inputs — VAUXP/VAUXN are 16-bit buses
        // VAUX0 is bit[0]. These ports connect directly to the
        // dedicated analog pads; no XDC constraint needed or allowed.
        .VAUXP     (16'b0000000000000001),  // VAUXP[0] tied high internally
        .VAUXN     (16'b0000000000000000),  // VAUXN[0] tied low internally
        .VP        (1'b0),
        .VN        (1'b0),

        // DRP interface — read result on every end-of-conversion
        .DADDR     (7'h10),      // VAUX0 result register address
        .DEN       (eoc_out),    // trigger read on EOC
        .DWE       (1'b0),
        .DI        (16'h0000),
        .DO        (do_out),     // [15:4] = 12-bit result, left-aligned
        .DRDY      (drdy_out),

        // Unused conversion control
        .CONVST    (1'b0),
        .CONVSTCLK (1'b0),

        // Status outputs
        .EOC       (eoc_out),
        .EOS       (eos_out),
        .BUSY      (busy_out),
        .CHANNEL   (channel_out),
        .ALM       ()
    );

    // Latch 12-bit result on data-ready strobe
    // XADC result is left-aligned in [15:4]; right-shift by 4 to extract
    // 0x000 = 0V, 0x800 = 0.5V, 0xFFF = 1V
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
