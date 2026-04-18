// spike_detector.v
// ──────────────────────────────────────────────────────────────────────────────
// Three-state FSM that detects incoming spikes from the 12-bit XADC sample
// stream, captures a fixed-length window, and extracts three temporal features.
//
// Features extracted (all Q8 normalized: value × 256 / WINDOW_SIZE):
//   F1 — spike width:   samples above threshold / WINDOW_SIZE
//   F2 — peak timing:   index of maximum sample / WINDOW_SIZE
//   F3 — rise ratio:    above-threshold samples before peak / total above threshold
//
// F2 and F3 are valid because the 12-bit XADC delivers amplitude information,
// allowing the true waveform peak to be located directly. A single-bit
// comparator cannot do this.
//
// Timing (at 1 MHz clock = 1 µs per cycle):
//   WINDOW_SIZE       = 1000 cycles = 1 ms
//   REFRACTORY_CYCLES = 10000 cycles = 10 ms
//   Total per spike   = 11 ms  <<  ISI_min of 500 ms

module spike_detector #(
    parameter WINDOW_SIZE        = 1000,   // sample window length (1 ms at 1 MHz)
    parameter REFRACTORY_CYCLES  = 10000,  // refractory period (10 ms at 1 MHz)
    parameter THRESHOLD          = 200     // 12-bit threshold: 200/4095 ≈ 49 mV
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] sample,        // 12-bit XADC sample
    input  wire        sample_valid,  // one-cycle strobe from xadc_sampler
    output reg         feature_valid, // one-cycle strobe: F1/F2/F3 are valid
    output reg  [7:0]  f1_width,      // Q8 spike width
    output reg  [7:0]  f2_timing,     // Q8 peak timing
    output reg  [7:0]  f3_ratio       // Q8 rise ratio
);

    // FSM state encoding
    localparam IDLE      = 2'd0;
    localparam CAPTURING = 2'd1;
    localparam COOLDOWN  = 2'd2;

    reg [1:0]  state        = IDLE;

    // Counter widths:
    //   sample_ctr:   needs to count to WINDOW_SIZE-1    = 999  → 10 bits
    //   cooldown_ctr: needs to count to REFRACTORY-1     = 9999 → 14 bits
    //   width_ctr:    counts above-threshold samples     = max WINDOW_SIZE → 10 bits
    //   rise_ctr:     counts above-threshold before peak = max WINDOW_SIZE → 10 bits
    reg [9:0]  sample_ctr   = 0;
    reg [13:0] cooldown_ctr = 0;
    reg [9:0]  width_ctr    = 0;
    reg [9:0]  rise_ctr     = 0;
    reg [9:0]  peak_idx     = 0;   // index of maximum sample
    reg [11:0] peak_val     = 0;   // maximum sample value seen so far
    reg        peaked       = 0;   // flag: have we passed the peak

    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            feature_valid <= 1'b0;
            sample_ctr    <= 0;
            cooldown_ctr  <= 0;
            width_ctr     <= 0;
            rise_ctr      <= 0;
            peak_idx      <= 0;
            peak_val      <= 0;
            peaked        <= 1'b0;
            f1_width      <= 8'h00;
            f2_timing     <= 8'h00;
            f3_ratio      <= 8'h00;
        end else begin
            feature_valid <= 1'b0;   // default: deassert each cycle

            // Only advance on valid XADC samples (once per µs at 1 MSPS)
            if (sample_valid) begin
                case (state)

                    // ── IDLE ────────────────────────────────────────────────
                    // Wait for a sample to cross the detection threshold.
                    IDLE: begin
                        if (sample > THRESHOLD) begin
                            state      <= CAPTURING;
                            sample_ctr <= 0;
                            width_ctr  <= 1;   // this sample is above threshold
                            rise_ctr   <= 0;
                            peak_idx   <= 0;
                            peak_val   <= sample;
                            peaked     <= 1'b0;
                        end
                    end

                    // ── CAPTURING ───────────────────────────────────────────
                    // Capture WINDOW_SIZE samples, track width, peak, rise.
                    CAPTURING: begin
                        sample_ctr <= sample_ctr + 1;

                        // F1: count samples above threshold
                        if (sample > THRESHOLD)
                            width_ctr <= width_ctr + 1;

                        // F2: track index of maximum sample (true peak)
                        if (sample > peak_val) begin
                            peak_val <= sample;
                            peak_idx <= sample_ctr;
                        end else if (!peaked && sample_ctr > 2) begin
                            // Sample fell below current peak — peak has passed
                            peaked <= 1'b1;
                        end

                        // F3: count above-threshold samples before peak
                        if (!peaked && sample > THRESHOLD)
                            rise_ctr <= rise_ctr + 1;

                        // Window complete — compute Q8 features
                        if (sample_ctr == WINDOW_SIZE - 1) begin

                            // F1 = width_ctr / WINDOW_SIZE  (Q8: ×256)
                            f1_width <= (width_ctr * 256) / WINDOW_SIZE;

                            // F2 = peak_idx / WINDOW_SIZE   (Q8: ×256)
                            f2_timing <= (peak_idx * 256) / WINDOW_SIZE;

                            // F3 = rise_ctr / width_ctr     (Q8: ×256)
                            // Guard against divide-by-zero when width_ctr = 0 (noise)
                            f3_ratio <= (width_ctr > 0) ?
                                        (rise_ctr * 256) / width_ctr :
                                        8'h00;

                            feature_valid <= 1'b1;
                            state         <= COOLDOWN;
                            cooldown_ctr  <= 0;
                        end
                    end

                    // ── COOLDOWN ─────────────────────────────────────────────
                    // Refractory period: wait for signal to return to baseline
                    // before accepting the next spike.
                    COOLDOWN: begin
                        if (cooldown_ctr == REFRACTORY_CYCLES - 1)
                            state <= IDLE;
                        else
                            cooldown_ctr <= cooldown_ctr + 1;
                    end

                    default: state <= IDLE;

                endcase
            end
        end
    end

endmodule
