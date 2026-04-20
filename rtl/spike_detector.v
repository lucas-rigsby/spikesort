// spike_detector.v  — FINAL CORRECTED VERSION
// Three-state FSM running at 100 MHz with sample_valid as clock enable.
//
// F1 overflow fix: result of (width_ctr * 256) / WINDOW_SIZE is computed
// in 18-bit intermediate and clamped to 255 before storing in 8-bit output.
// This is critical for Neuron B whose spike (~1.8 ms at 310mV) is wider
// than the 1 ms capture window — width_ctr reaches WINDOW_SIZE=1000,
// giving (1000*256)/1000 = 256 which truncated to 8 bits = 0x00 (wrong).
// Clamping gives 0xFF = 255, correctly indicating a wide spike.

module spike_detector #(
    parameter WINDOW_SIZE       = 1000,
    parameter REFRACTORY_CYCLES = 10000,
    parameter THRESHOLD         = 200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        ce,            // high on each XADC sample (sample_valid)
    input  wire [11:0] sample,
    output reg         feature_valid,
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

    // 18-bit intermediate for division result before clamping to 8 bits
    reg [17:0] f1_raw, f2_raw, f3_raw;

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

                IDLE: begin
                    if (ce && (sample > THRESHOLD)) begin
                        state      <= CAPTURING;
                        sample_ctr <= 0;
                        width_ctr  <= 1;
                        rise_ctr   <= 1;
                        peak_idx   <= 0;
                        peak_val   <= sample;
                        peaked     <= 1'b0;
                    end
                end

                CAPTURING: begin
                    if (ce) begin
                        sample_ctr <= sample_ctr + 1;

                        if (sample > THRESHOLD)
                            width_ctr <= width_ctr + 1;

                        if (sample > peak_val) begin
                            peak_val <= sample;
                            peak_idx <= sample_ctr;
                        end else if (!peaked && sample_ctr > 2) begin
                            peaked <= 1'b1;
                        end

                        if (!peaked && sample > THRESHOLD)
                            rise_ctr <= rise_ctr + 1;

                        if (sample_ctr == WINDOW_SIZE - 1) begin

                            // Compute Q8 features with overflow protection.
                            // All divisions produce results in range [0, 256].
                            // Clamp to 255 (8'hFF) if result would overflow 8 bits.

                            // F1: spike width
                            f1_raw = (width_ctr * 256) / WINDOW_SIZE;
                            f1_width <= (f1_raw > 255) ? 8'hFF : f1_raw[7:0];

                            // F2: peak timing
                            f2_raw = (peak_idx * 256) / WINDOW_SIZE;
                            f2_timing <= (f2_raw > 255) ? 8'hFF : f2_raw[7:0];

                            // F3: rise ratio
                            if (width_ctr > 0) begin
                                f3_raw = (rise_ctr * 256) / width_ctr;
                                f3_ratio <= (f3_raw > 255) ? 8'hFF : f3_raw[7:0];
                            end else begin
                                f3_ratio <= 8'h00;
                            end

                            feature_valid <= 1'b1;
                            state         <= COOLDOWN;
                            cooldown_ctr  <= 0;
                        end
                    end
                end

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
