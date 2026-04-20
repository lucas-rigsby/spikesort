// spike_sorter_top.v
// Top-level for SpikeSort on Basys-3 (xc7a35tcpg236-1).
// Single 100 MHz clock 

// LEDs:
//   led[0] SNN output Neuron A  led[1] SNN output Neuron B
//   led[2] SNN output Noise     led[3] classification[0]
//   led[4] spike_seen latch (goes high after first spike, reset by btnC)

module spike_sorter_top (
    input  wire        clk,      // W5  100 MHz
    input  wire        btnC,     // U18 active-high reset
    output wire [4:0]  led,
    output wire [6:0]  seg,
    output wire [3:0]  an
);

    // XADC
    wire [11:0] sample;
    wire        sample_valid;

    xadc_sampler u_xadc (
        .clk          (clk),
        .rst          (btnC),
        .sample       (sample),
        .sample_valid (sample_valid)
    );

    // Spike detector
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

    // Rate encoder
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
            end else
                encode_ctr <= encode_ctr + 1;
        end
    end

    wire [2:0] in_spikes;
    assign in_spikes[0] = encoding_active && (lfsr < f1_lat);
    assign in_spikes[1] = encoding_active && (lfsr < f2_lat);
    assign in_spikes[2] = encoding_active && (lfsr < f3_lat);

    // SNN classifier
    wire [2:0] out_spikes;

    snn_core u_snn (
        .clk       (clk),
        .rst       (btnC),
        .in_spike  (in_spikes),
        .out_spike (out_spikes)
    );

    // Vote decoder
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

    // Display
    seg7_controller u_seg (
        .clk            (clk),
        .classification (classification),
        .result_valid   (result_valid),
        .seg            (seg),
        .an             (an)
    );

    // Spike-seen latch
    reg spike_seen = 0;
    always @(posedge clk) begin
        if (btnC)
            spike_seen <= 1'b0;
        else if (feature_valid)
            spike_seen <= 1'b1;
    end

    assign led[0] = out_spikes[0];
    assign led[1] = out_spikes[1];
    assign led[2] = out_spikes[2];
    assign led[3] = classification[0];
    assign led[4] = spike_seen;

endmodule
