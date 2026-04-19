// spike_sorter_top.v
// ──────────────────────────────────────────────────────────────────────────────
// Top-level module for SpikeSort on Basys-3 (xc7a35tcpg236-1).
//
// NOTE: vp_in and vn_in have been removed as top-level ports.
// The XADC VAUXP[0]/VAUXN[0] analog inputs (J3/K3 on JXADC header) are
// connected internally inside xadc_sampler.v via the XADC primitive.
// No XDC constraint is needed or allowed for these pins.
//
// Pipeline:
//   xadc_sampler  -> spike_detector -> rate encoder -> snn_core
//                 -> output_decoder -> seg7_controller

module spike_sorter_top (
    input  wire        clk,       // W5  — 100 MHz onboard oscillator
    input  wire        btnC,      // U18 — center button, active-high reset
    output wire [4:0]  led,       // [2:0]=SNN spikes, [4:3]=classification
    output wire [6:0]  seg,       // 7-segment segments (active low)
    output wire [3:0]  an         // 7-segment anodes (active low)
);

    // ── 1 MHz clock divider for spike detector ─────────────────────────────
    reg [5:0] clk_div  = 0;
    reg       clk_1mhz = 0;

    always @(posedge clk) begin
        if (clk_div == 6'd49) begin
            clk_div  <= 0;
            clk_1mhz <= ~clk_1mhz;
        end else begin
            clk_div  <= clk_div + 1;
        end
    end

    // ── Internal signals ───────────────────────────────────────────────────
    wire [11:0] sample;
    wire        sample_valid;

    wire [7:0]  f1_width, f2_timing, f3_ratio;
    wire        feature_valid;

    wire [2:0]  in_spikes;
    wire [2:0]  out_spikes;

    wire [1:0]  classification;
    wire        result_valid;

    // ── Stage 1: XADC — 12-bit samples at ~960 KSPS ───────────────────────
    // No top-level analog ports — VAUXP[0]/VAUXN[0] connected internally
    xadc_sampler u_xadc (
        .clk          (clk),
        .rst          (btnC),
        .sample       (sample),
        .sample_valid (sample_valid)
    );

    // ── Stage 2: Spike detector FSM at 1 MHz ──────────────────────────────
    spike_detector #(
        .WINDOW_SIZE       (1000),
        .REFRACTORY_CYCLES (10000),
        .THRESHOLD         (200)
    ) u_detect (
        .clk           (clk_1mhz),
        .rst           (btnC),
        .sample        (sample),
        .sample_valid  (sample_valid),
        .feature_valid (feature_valid),
        .f1_width      (f1_width),
        .f2_timing     (f2_timing),
        .f3_ratio      (f3_ratio)
    );

    // ── Stage 3: Rate encoder — Q8 features -> Poisson spike trains ───────
    reg [7:0] lfsr = 8'hAC;

    always @(posedge clk) begin
        lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    reg [7:0] f1_lat = 0, f2_lat = 0, f3_lat = 0;
    reg       encoding_active = 0;
    reg [7:0] encode_ctr      = 0;

    always @(posedge clk) begin
        if (btnC) begin
            f1_lat <= 0; f2_lat <= 0; f3_lat <= 0;
            encoding_active <= 1'b0;
            encode_ctr      <= 0;
        end else begin
            if (feature_valid) begin
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
    end

    assign in_spikes[0] = encoding_active && (lfsr < f1_lat);
    assign in_spikes[1] = encoding_active && (lfsr < f2_lat);
    assign in_spikes[2] = encoding_active && (lfsr < f3_lat);

    // ── Stage 4: SNN classifier — 3->6->3 LIF network ─────────────────────
    snn_core u_snn (
        .clk       (clk),
        .rst       (btnC),
        .in_spike  (in_spikes),
        .out_spike (out_spikes)
    );

    // ── Stage 5: Population vote decoder ──────────────────────────────────
    output_decoder #(
        .VOTE_WINDOW (256)
    ) u_decode (
        .clk            (clk),
        .rst            (btnC),
        .out_spike      (out_spikes),
        .classification (classification),
        .result_valid   (result_valid)
    );

    // ── Stage 6: 7-segment display ─────────────────────────────────────────
    seg7_controller u_seg (
        .clk            (clk),
        .classification (classification),
        .result_valid   (result_valid),
        .seg            (seg),
        .an             (an)
    );

    // ── LEDs ───────────────────────────────────────────────────────────────
    assign led[2:0] = out_spikes;
    assign led[4:3] = classification;

endmodule
