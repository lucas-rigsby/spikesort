// spike_detector.v
// Three-state FSM: IDLE -> CAPTURING -> COOLDOWN.
//
// Runs entirely in the 100 MHz clock domain using a clock enable (ce)
// signal that is high once per microsecond. This avoids using a
// register-generated clock as a module clock, which causes Vivado CDC
// and timing analysis problems.
//
// sample[11:0] and sample_valid are produced by xadc_sampler in the
// same 100 MHz domain — no clock domain crossing required.
//
// Features extracted (Q8 normalised: value * 256 / WINDOW_SIZE):
//   F1 — spike width   : samples above threshold / WINDOW_SIZE
//   F2 — peak timing   : index of maximum sample / WINDOW_SIZE
//   F3 — rise ratio    : above-threshold samples before peak / total above threshold
//
// WINDOW_SIZE = 1000 at 1 MSPS = 1 ms capture window
// REFRACTORY  = 10000 cycles   = 10 ms refractory period

module spike_detector #(
    parameter WINDOW_SIZE       = 1000,
    parameter REFRACTORY_CYCLES = 10000,
    parameter THRESHOLD         = 200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,            // clock enable: high for 1 cycle per µs
    input  wire [11:0] sample,        // 12-bit XADC sample (valid when ce=1)
    output reg         feature_valid, // one-cycle strobe: features ready
    output reg  [7:0]  f1_width,
    output reg  [7:0]  f2_timing,
    output reg  [7:0]  f3_ratio
);

    localparam IDLE      = 2'd0;
    localparam CAPTURING = 2'd1;
    localparam COOLDOWN  = 2'd2;

    reg [1:0]  state        = IDLE;
    reg [9:0]  sample_ctr   = 0;
    reg [13:0] cooldown_ctr = 0;
    reg [9:0]  width_ctr    = 0;
    reg [9:0]  rise_ctr     = 0;
    reg [9:0]  peak_idx     = 0;
    reg [11:0] peak_val     = 0;
    reg        peaked       = 0;

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
            feature_valid <= 1'b0;

            case (state)

                // ── IDLE ──────────────────────────────────────────────────
                IDLE: begin
                    if (ce && (sample > THRESHOLD)) begin
                        state      <= CAPTURING;
                        sample_ctr <= 0;
                        width_ctr  <= 1;    // triggering sample counts
                        rise_ctr   <= 1;    // triggering sample is pre-peak
                        peak_idx   <= 0;
                        peak_val   <= sample;
                        peaked     <= 1'b0;
                    end
                end

                // ── CAPTURING ─────────────────────────────────────────────
                CAPTURING: begin
                    if (ce) begin
                        sample_ctr <= sample_ctr + 1;

                        // F1: count samples above threshold
                        if (sample > THRESHOLD)
                            width_ctr <= width_ctr + 1;

                        // F2: track index of maximum sample
                        if (sample > peak_val) begin
                            peak_val <= sample;
                            peak_idx <= sample_ctr;
                        end else if (!peaked && sample_ctr > 2) begin
                            peaked <= 1'b1;
                        end

                        // F3: above-threshold samples before peak
                        if (!peaked && sample > THRESHOLD)
                            rise_ctr <= rise_ctr + 1;

                        if (sample_ctr == WINDOW_SIZE - 1) begin
                            // Compute Q8 features
                            f1_width  <= (width_ctr * 256) / WINDOW_SIZE;
                            f2_timing <= (peak_idx  * 256) / WINDOW_SIZE;
                            f3_ratio  <= (width_ctr > 0) ?
                                         (rise_ctr  * 256) / width_ctr :
                                         8'h00;
                            feature_valid <= 1'b1;
                            state         <= COOLDOWN;
                            cooldown_ctr  <= 0;
                        end
                    end
                end

                // ── COOLDOWN ──────────────────────────────────────────────
                // Count time regardless of sample_valid / ce.
                // Using full 100 MHz clock ensures accurate timing.
                // REFRACTORY_CYCLES is scaled accordingly:
                //   at 100 MHz, 1 ms = 100000 cycles, 10 ms = 1000000 cycles
                // However we use ce-gated counting to keep the parameter
                // meaning consistent (REFRACTORY_CYCLES at 1 MSPS rate).
                COOLDOWN: begin
                    if (ce) begin
                        if (cooldown_ctr == REFRACTORY_CYCLES - 1)
                            state <= IDLE;
                        else
                            cooldown_ctr <= cooldown_ctr + 1;
                    end
                end

                default: state <= IDLE;

            endcase
        end
    end

endmodule
