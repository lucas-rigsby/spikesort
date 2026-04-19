//   led[0]  — sample_valid pulses (will flicker very fast at ~960 KSPS)
//             If this never flickers: XADC is not producing samples
//   led[1]  — spike_detector triggered: pulses for 1 cycle on feature_valid
//             Stretched to ~500ms so it is visible to the eye
//             If led[0] flickers but led[1] never lights: threshold not crossed
//   led[2]  — encoding_active: high during 256-cycle SNN integration window
//             Will be on briefly after each spike
//   led[3]  — result_valid stretched: pulses after each classification
//             If led[2] lights but led[3] never: vote decoder issue
//   led[4]  — spike_seen latch: stays on permanently after first spike
//             Press btnC to reset

 
module spike_sorter_top (
    input  wire        clk,
    input  wire        btnC,
    output wire [4:0]  led,
    output wire [6:0]  seg,
    output wire [3:0]  an
);
 
    // ── XADC ──────────────────────────────────────────────────────────────
    wire [11:0] sample;
    wire        sample_valid;
 
    xadc_sampler u_xadc (
        .clk          (clk),
        .rst          (btnC),
        .sample       (sample),
        .sample_valid (sample_valid)
    );
 
    // ── Spike detector ─────────────────────────────────────────────────────
    wire        feature_valid;
    wire [7:0]  f1_width, f2_timing, f3_ratio;
 
    spike_detector #(
        .WINDOW_SIZE       (1000),
        .REFRACTORY_CYCLES (10000),
        .THRESHOLD         (200)
    ) u_detect (
        .clk           (clk),
        .rst           (btnC),
        .ce            (sample_valid),
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
            f1_lat <= 0; f2_lat <= 0; f3_lat <= 0;
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
            end else
                encode_ctr <= encode_ctr + 1;
        end
    end
 
    wire [2:0] in_spikes;
    assign in_spikes[0] = encoding_active && (lfsr < f1_lat);
    assign in_spikes[1] = encoding_active && (lfsr < f2_lat);
    assign in_spikes[2] = encoding_active && (lfsr < f3_lat);
 
    // ── SNN ───────────────────────────────────────────────────────────────
    wire [2:0] out_spikes;
    snn_core u_snn (.clk(clk), .rst(btnC), .in_spike(in_spikes), .out_spike(out_spikes));
 
    // ── Vote decoder ───────────────────────────────────────────────────────
    wire [1:0] classification;
    wire       result_valid;
    output_decoder #(.VOTE_WINDOW(256)) u_decode (
        .clk(clk), .rst(btnC),
        .out_spike(out_spikes), .spike_active(encoding_active),
        .classification(classification), .result_valid(result_valid)
    );
 
    // ── Display ───────────────────────────────────────────────────────────
    seg7_controller u_seg (
        .clk(clk), .classification(classification),
        .result_valid(result_valid), .seg(seg), .an(an)
    );
 
    // ── Diagnostic LED stretchers ─────────────────────────────────────────
    // Stretch short pulses to ~500 ms so they are visible on LEDs.
    // A 100 MHz counter needs 27 bits to reach 50,000,000 (0.5 s).
 
    // LED[0]: sample_valid — stretches XADC activity to visible blink
    reg [26:0] sv_stretch = 0;
    always @(posedge clk) begin
        if (btnC)            sv_stretch <= 0;
        else if (sample_valid) sv_stretch <= 27'd5_000_000; // 50ms visible pulse
        else if (sv_stretch > 0) sv_stretch <= sv_stretch - 1;
    end
 
    // LED[1]: feature_valid — stretches spike detection event
    reg [26:0] fv_stretch = 0;
    always @(posedge clk) begin
        if (btnC)             fv_stretch <= 0;
        else if (feature_valid) fv_stretch <= 27'd50_000_000; // 500ms
        else if (fv_stretch > 0) fv_stretch <= fv_stretch - 1;
    end
 
    // LED[3]: result_valid — stretches classification event
    reg [26:0] rv_stretch = 0;
    always @(posedge clk) begin
        if (btnC)            rv_stretch <= 0;
        else if (result_valid) rv_stretch <= 27'd50_000_000; // 500ms
        else if (rv_stretch > 0) rv_stretch <= rv_stretch - 1;
    end
 
    // LED[4]: spike_seen latch
    reg spike_seen = 0;
    always @(posedge clk) begin
        if (btnC)          spike_seen <= 1'b0;
        else if (feature_valid) spike_seen <= 1'b1;
    end
 
    // ── LED assignments ────────────────────────────────────────────────────
    assign led[0] = (sv_stretch > 0);       // XADC producing samples
    assign led[1] = (fv_stretch > 0);       // spike detector triggered
    assign led[2] = encoding_active;         // SNN integration active
    assign led[3] = (rv_stretch > 0);       // vote decoder fired
    assign led[4] = spike_seen;             // permanent latch
 
endmodule