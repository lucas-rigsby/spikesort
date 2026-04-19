// spike_sorter_top.v
// Top-level for SpikeSort on Basys-3 (xc7a35tcpg236-1).
//
// All logic runs in the single 100 MHz clock domain.
// The spike detector uses a clock enable (ce_1mhz) that pulses high
// for one cycle every microsecond, replacing the divided clock approach.
// This eliminates all clock domain crossing issues:
//   - sample[11:0] never crosses domains
//   - feature_valid never crosses domains
//   - No register-generated clock used as a module clock port
//
// LED assignments:
//   led[0] — SNN output spike Neuron A  (flickers at spike rate)
//   led[1] — SNN output spike Neuron B
//   led[2] — SNN output spike Noise
//   led[3] — classification bit 0  (latched, 0=A/noise, 1=B/noise)
//   led[4] — spike_seen: latches HIGH after first valid spike detected.
//            If this never lights with signal applied, spike detector is
//            not triggering — check analog amplitude at JXADC J3.

module spike_sorter_top (
    input  wire        clk,      // W5  100 MHz
    input  wire        btnC,     // U18 active-high reset
    output wire [4:0]  led,
    output wire [6:0]  seg,
    output wire [3:0]  an
);

    // ── 1 µs clock enable ─────────────────────────────────────────────────
    // Pulses high for exactly one 100 MHz cycle every 100 cycles (= 1 µs).
    // Passed as 'ce' to spike_detector instead of a divided clock.
    reg [6:0] ce_ctr   = 0;
    reg       ce_1mhz  = 0;

    always @(posedge clk) begin
        if (btnC) begin
            ce_ctr  <= 0;
            ce_1mhz <= 1'b0;
        end else if (ce_ctr == 7'd99) begin
            ce_ctr  <= 0;
            ce_1mhz <= 1'b1;
        end else begin
            ce_ctr  <= ce_ctr + 1;
            ce_1mhz <= 1'b0;
        end
    end

    // ── XADC — 100 MHz domain ─────────────────────────────────────────────
    wire [11:0] sample;
    wire        sample_valid;   // one-cycle 100 MHz pulse

    xadc_sampler u_xadc (
        .clk          (clk),
        .rst          (btnC),
        .sample       (sample),
        .sample_valid (sample_valid)
    );

    // ── Spike detector — 100 MHz clock, 1 µs clock enable ─────────────────
    // sample and sample_valid are in the 100 MHz domain.
    // ce_1mhz gates the FSM so it advances once per microsecond, matching
    // the XADC ~960 KSPS rate (one sample every ~1.04 µs).
    // We use sample_valid as ce rather than ce_1mhz so the FSM advances
    // exactly when a new sample arrives, regardless of minor XADC timing
    // variation. sample_valid already occurs at ~1 µs intervals.
    wire        feature_valid;
    wire [7:0]  f1_width, f2_timing, f3_ratio;

    spike_detector #(
        .WINDOW_SIZE       (1000),
        .REFRACTORY_CYCLES (10000),
        .THRESHOLD         (200)
    ) u_detect (
        .clk           (clk),
        .rst           (btnC),
        .ce            (sample_valid),   // advance FSM on each XADC sample
        .sample        (sample),
        .feature_valid (feature_valid),
        .f1_width      (f1_width),
        .f2_timing     (f2_timing),
        .f3_ratio      (f3_ratio)
    );

    // ── Rate encoder ───────────────────────────────────────────────────────
    reg [7:0] lfsr = 8'hAC;
    always @(posedge clk)
        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};

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

    // ── Vote decoder ───────────────────────────────────────────────────────
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
    reg spike_seen = 0;
    always @(posedge clk) begin
        if (btnC)
            spike_seen <= 1'b0;
        else if (feature_valid)
            spike_seen <= 1'b1;
    end

    // ── LEDs ──────────────────────────────────────────────────────────────
    assign led[0] = out_spikes[0];
    assign led[1] = out_spikes[1];
    assign led[2] = out_spikes[2];
    assign led[3] = classification[0];
    assign led[4] = spike_seen;

endmodule
