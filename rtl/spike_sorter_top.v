// spike_sorter_top.v
// Top-level module for SpikeSort on Basys-3 (xc7a35tcpg236-1).
// Connects all pipeline stages: sync → detect → encode → SNN → decode → display.
//
// Pin assignments (set in spikesort.xdc):
//   clk   → W5  (100 MHz onboard oscillator)
//   btnC  → U18 (center pushbutton, active-high reset)
//   JA[0] → J1  (Pmod JA pin 1 — comparator output from breadboard)

module spike_sorter_top (
    input  wire        clk,
    input  wire        btnC,
    input  wire [7:0]  JA,
    output wire [15:0] led,
    output wire [6:0]  seg,
    output wire [3:0]  an
);

    // Internal signals
    wire        spike_sync;
    wire [7:0]  f1_width;
    wire [7:0]  f2_timing;
    wire        feature_valid;
    wire [1:0]  in_spikes;
    wire [2:0]  out_spikes;
    wire [1:0]  classification;
    wire        result_valid;

    // Stage 1: Metastability synchronizer
    input_sync u_sync (
        .clk      (clk),
        .async_in (JA[0]),
        .sync_out (spike_sync)
    );

    // Stage 2: Spike detector + feature extractor
    spike_detector #(
        .WINDOW_SIZE       (512),
        .REFRACTORY_CYCLES (2000)
    ) u_detect (
        .clk           (clk),
        .rst           (btnC),
        .spike_in      (spike_sync),
        .feature_valid (feature_valid),
        .f1_width      (f1_width),
        .f2_timing     (f2_timing)
    );

    // Stage 3: Rate encoder — MSB of each Q8 feature used as spike probability
    assign in_spikes = feature_valid ? {f1_width[7], f2_timing[7]} : 2'b00;

    // Stage 4: SNN classifier (LIF network)
    snn_core u_snn (
        .clk       (clk),
        .rst       (btnC),
        .in_spike  (in_spikes),
        .out_spike (out_spikes)
    );

    // Stage 5: Population vote decoder
    output_decoder #(
        .VOTE_WINDOW (256)
    ) u_decode (
        .clk            (clk),
        .rst            (btnC),
        .out_spike      (out_spikes),
        .classification (classification),
        .result_valid   (result_valid)
    );

    // Stage 6: 7-segment display driver
    seg7_controller u_seg (
        .clk            (clk),
        .classification (classification),
        .result_valid   (result_valid),
        .seg            (seg),
        .an             (an)
    );

    // LED indicators
    // [2:0]  — raw output neuron spikes (live activity)
    // [4:3]  — latched classification code
    // [15:5] — unused, driven low
    assign led[2:0]  = out_spikes;
    assign led[4:3]  = classification;
    assign led[15:5] = 11'b0;

endmodule
