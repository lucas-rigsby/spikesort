// xadc_sampler.v
// ──────────────────────────────────────────────────────────────────────────────
// Instantiates the Artix-7 XADC primitive for single-channel continuous
// sampling on VAUXP[0]/VAUXN[0] (JXADC header pins J3/K3 on Basys-3).
//
// Configuration:
//   Channel:     VAUX0 (DRP address 0x10)
//   Mode:        Single channel, continuous
//   ADC clock:   100 MHz / 4 = 25 MHz  → ~960 KSPS
//   Resolution:  12-bit, unipolar 0–1V
//   DRP read:    Triggered on every EOC (end-of-conversion) pulse
//
// Output:
//   sample[11:0]  — 12-bit result, 0x000=0V, 0xFFF=1V
//   sample_valid  — one-cycle strobe when sample is valid
//
// Input filter (external, on breadboard):
//   100Ω series resistor + 10nF differential cap between VP and VN
//   f_c = 1/(2π×100×10nF) ≈ 159 kHz  — passes spike content, rejects FPGA noise

module xadc_sampler (
    input  wire        clk,          // 100 MHz system clock
    input  wire        rst,
    input  wire        vp_in,        // VAUXP[0] — JXADC J3
    input  wire        vn_in,        // VAUXN[0] — JXADC K3
    output reg  [11:0] sample,       // 12-bit ADC result
    output reg         sample_valid  // one-cycle strobe
);

    wire [15:0] do_out;
    wire        drdy_out;
    wire        busy_out;
    wire [4:0]  channel_out;
    wire        eoc_out;
    wire        eos_out;

    // ── XADC primitive ────────────────────────────────────────────────────────
    XADC #(
        // Configuration Register 0 (INIT_40)
        //   [13:12] = 00  → single channel (not sequencer)
        //   [8]     =  1  → enable auxiliary analog inputs
        .INIT_40 (16'h9000),

        // Configuration Register 1 (INIT_41)
        //   [15:12] = 0001 → continuous sampling mode
        //   [5:0]   = 010000 → channel address 0x10 = VAUX0
        .INIT_41 (16'h10C0),

        // Configuration Register 2 (INIT_42)
        //   [15:8] = 0x04 → ADC clock divider = 4
        //   f_ADC = 100 MHz / 4 = 25 MHz → conversion time = 26/25MHz ≈ 1.04 µs
        .INIT_42 (16'h0400),

        // Unused configuration registers — set to reset default
        .INIT_43 (16'h0000),
        .INIT_44 (16'h0000),
        .INIT_45 (16'h0000),
        .INIT_46 (16'h0000),
        .INIT_47 (16'h0000),

        // Sequencer channel selection (INIT_48)
        //   Bit [1] = 1 → enable VAUX0 in sequencer (used even in single-ch mode)
        .INIT_48 (16'h0002),
        .INIT_49 (16'h0000),
        .INIT_4A (16'h0000),
        .INIT_4B (16'h0000),
        .INIT_4C (16'h0000),
        .INIT_4D (16'h0000),
        .INIT_4E (16'h0000),
        .INIT_4F (16'h0000),

        // Alarm thresholds — Xilinx defaults, not used in this design
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
        // Clock and reset
        .DCLK      (clk),
        .RESET     (rst),

        // Analog inputs
        // VAUXP/VAUXN are 16-bit buses; VAUX0 is bit [0]
        .VAUXP     ({15'b0, vp_in}),
        .VAUXN     ({15'b0, vn_in}),
        .VP        (1'b0),           // dedicated VP/VN pair not used
        .VN        (1'b0),

        // DRP interface
        .DADDR     (7'h10),          // read VAUX0 result register
        .DEN       (eoc_out),        // read on every end-of-conversion
        .DWE       (1'b0),           // no register writes
        .DI        (16'h0000),
        .DO        (do_out),         // 16-bit output, result in [15:4]
        .DRDY      (drdy_out),       // data-ready strobe

        // Conversion control — unused (continuous mode)
        .CONVST    (1'b0),
        .CONVSTCLK (1'b0),

        // Status
        .EOC       (eoc_out),
        .EOS       (eos_out),
        .BUSY      (busy_out),
        .CHANNEL   (channel_out),
        .ALM       ()                // alarm outputs unused
    );

    // ── Result latch ──────────────────────────────────────────────────────────
    // XADC stores result left-aligned: bits [15:4] = 12-bit value, [3:0] = 0
    // Right-shift by 4 to extract:  0x000 = 0V,  0x800 = 0.5V,  0xFFF = 1V
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
