// spike_sorter_top.v
// Top-level for SpikeSort on Basys-3 (xc7a35tcpg236-1).
//
// ── Clock domains ──────────────────────────────────────────────────────────
//   clk       100 MHz  XADC, rate encoder, SNN, decoder, display
//   clk_1mhz    1 MHz  spike detector FSM
//
// ── Clock domain crossing (CDC) fixes ──────────────────────────────────────
//
//   CDC 1 — sample_valid (100 MHz -> 1 MHz)
//     XADC produces a 1-cycle 100 MHz pulse (~10 ns).
//     The 1 MHz spike detector period is 1000 ns — the pulse would be
//     missed 99% of the time without stretching.
//     Fix: set a flag on the 100 MHz edge, clear it after the 1 MHz
//     domain has seen it (detected via clk_1mhz rising edge in 100 MHz domain).
//
//   CDC 2 — feature_valid (1 MHz -> 100 MHz)
//     feature_valid is a 1-cycle 1 MHz pulse (1000 ns wide = 100 cycles at
//     100 MHz). This is wide enough to be seen reliably in the 100 MHz
//     domain — no stretching required. Two flip-flop synchroniser added
//     for metastability safety.
//
// ── LED assignments ────────────────────────────────────────────────────────
//   led[0]  — SNN output spike: Neuron A  (flickers at spike rate)
//   led[1]  — SNN output spike: Neuron B
//   led[2]  — SNN output spike: Noise
//   led[3]  — classification bit 0  (latched)
//   led[4]  — spike_seen: latches HIGH after first valid spike detected
//             Useful for debug: confirms spike detector is triggering.
//             Press btnC to reset.

module spike_sorter_top (
    input  wire        clk,      // W5  100 MHz
    input  wire        btnC,     // U18 active-high reset
    output wire [4:0]  led,
    output wire [6:0]  seg,
    output wire [3:0]  an
);

    // ── 1 MHz clock divider ────────────────────────────────────────────────
    reg [5:0] clk_div  = 0;
    reg       clk_1mhz = 0;

    always @(posedge clk) begin
        if (btnC) begin
            clk_div  <= 0;
            clk_1mhz <= 0;
        end else if (clk_div == 6'd49) begin
            clk_div  <= 0;
            clk_1mhz <= ~clk_1mhz;
        end else begin
            clk_div  <= clk_div + 1;
        end
    end

    // ── XADC ──────────────────────────────────────────────────────────────
    wire [11:0] sample;
    wire        sample_valid_100;   // 1-cycle pulse at 100 MHz

    xadc_sampler u_xadc (
        .clk          (clk),
        .rst          (btnC),
        .sample       (sample),
        .sample_valid (sample_valid_100)
    );

    // ── CDC 1: stretch sample_valid for 1 MHz domain ───────────────────────
    // Detect rising edge of clk_1mhz in 100 MHz domain
    reg clk_1mhz_r = 0;
    always @(posedge clk) clk_1mhz_r <= clk_1mhz;
    wire clk_1mhz_rise = clk_1mhz & ~clk_1mhz_r;

    // Set flag on XADC delivery, clear after 1 MHz domain has seen it
    reg sample_valid_stretched = 0;
    always @(posedge clk) begin
        if (btnC)
            sample_valid_stretched <= 1'b0;
        else if (sample_valid_100)
            sample_valid_stretched <= 1'b1;
        else if (clk_1mhz_rise)
            sample_valid_stretched <= 1'b0;
    end

    // ── Spike detector at 1 MHz ────────────────────────────────────────────
    wire        feature_valid_1mhz;
    wire [7:0]  f1_width, f2_timing, f3_ratio;

    spike_detector #(
        .WINDOW_SIZE       (1000),
        .REFRACTORY_CYCLES (10000),
        .THRESHOLD         (200)
    ) u_detect (
        .clk           (clk_1mhz),
        .rst           (btnC),
        .sample        (sample),
        .sample_valid  (sample_valid_stretched),
        .feature_valid (feature_valid_1mhz),
        .f1_width      (f1_width),
        .f2_timing     (f2_timing),
        .f3_ratio      (f3_ratio)
    );

    // ── CDC 2: synchronise feature_valid into 100 MHz domain ──────────────
    // feature_valid_1mhz is 1000 ns wide (100 cycles at 100 MHz) so a
    // 2-FF synchroniser is sufficient — no stretching needed.
    reg fv_sync1 = 0, fv_sync2 = 0;
    always @(posedge clk) begin
        fv_sync1 <= feature_valid_1mhz;
        fv_sync2 <= fv_sync1;
    end
    wire feature_valid = fv_sync2;

    // ── Rate encoder ───────────────────────────────────────────────────────
    // 8-bit Fibonacci LFSR — maximal length 255-cycle sequence
    reg [7:0] lfsr = 8'hAC;
    always @(posedge clk)
        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

    // Latch features and run 256-cycle encoding window
    reg [7:0] f1_lat = 0, f2_lat = 0, f3_lat = 0;
    reg       encoding_active = 0;
    reg [7:0] encode_ctr      = 0;

    always @(posedge clk) begin
        if (btnC) begin
            f1_lat          <= 0;
            f2_lat          <= 0;
            f3_lat          <= 0;
            encoding_active <= 1'b0;
            encode_ctr      <= 0;
        end else if (feature_valid) begin
            f1_lat          <= f1_width;
            f2_lat          <= f2_timing;
            f3_lat          <= f3_ratio;
            encoding_active <= 1'b1;
            encode_ctr      <= 0;
        end else if (encoding_active) begin
            if (encode_ctr == 8'd255) begin
                encoding_active <= 1'b0;
                encode_ctr      <= 0;
            end else begin
                encode_ctr <= encode_ctr + 1;
            end
        end
    end

    wire [2:0] in_spikes;
    assign in_spikes[0] = encoding_active && (lfsr < f1_lat);
    assign in_spikes[1] = encoding_active && (lfsr < f2_lat);
    assign in_spikes[2] = encoding_active && (lfsr < f3_lat);

    // ── SNN classifier ─────────────────────────────────────────────────────
    wire [2:0] out_spikes;

    snn_core u_snn (
        .clk       (clk),
        .rst       (btnC),
        .in_spike  (in_spikes),
        .out_spike (out_spikes)
    );

    // ── Vote decoder (gated on encoding_active) ────────────────────────────
    wire [1:0] classification;
    wire       result_valid;

    output_decoder #(
        .VOTE_WINDOW (256)
    ) u_decode (
        .clk            (clk),
        .rst            (btnC),
        .out_spike      (out_spikes),
        .spike_active   (encoding_active),
        .classification (classification),
        .result_valid   (result_valid)
    );

    // ── 7-segment display ──────────────────────────────────────────────────
    seg7_controller u_seg (
        .clk            (clk),
        .classification (classification),
        .result_valid   (result_valid),
        .seg            (seg),
        .an             (an)
    );

    // ── Spike-seen debug latch ─────────────────────────────────────────────
    // LED[4] latches HIGH after the first valid feature_valid pulse.
    // If this LED never lights when a signal is applied, the spike detector
    // is not triggering — check analog signal amplitude at JXADC J3.
    // Press btnC to reset this indicator.
    reg spike_seen = 0;
    always @(posedge clk) begin
        if (btnC)
            spike_seen <= 1'b0;
        else if (feature_valid)
            spike_seen <= 1'b1;
    end

    // ── LED assignments ────────────────────────────────────────────────────
    assign led[0] = out_spikes[0];      // live Neuron A SNN spike
    assign led[1] = out_spikes[1];      // live Neuron B SNN spike
    assign led[2] = out_spikes[2];      // live Noise SNN spike
    assign led[3] = classification[0];  // latched classification bit 0
    assign led[4] = spike_seen;         // debug: goes high after first spike

endmodule
