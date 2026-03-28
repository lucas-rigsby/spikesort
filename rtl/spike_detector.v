// spike_detector.v
// Detects rising edges on the synchronized spike input, opens a capture
// window, measures spike width (F1) and peak timing (F2), outputs both
// as Q8 normalized 8-bit values. Enforces a refractory cooldown period
// between detections to prevent double-counting.

module spike_detector #(
    parameter WINDOW_SIZE        = 512,
    parameter REFRACTORY_CYCLES  = 2000
)(
    input  wire      clk,
    input  wire      rst,
    input  wire      spike_in,
    output reg       feature_valid,
    output reg [7:0] f1_width,
    output reg [7:0] f2_timing
);

    // FSM state encoding
    localparam IDLE      = 2'd0;
    localparam CAPTURING = 2'd1;
    localparam COOLDOWN  = 2'd2;

    reg [1:0]  state        = IDLE;
    reg [9:0]  sample_ctr   = 0;
    reg [10:0] cooldown_ctr = 0;
    reg [9:0]  width_ctr    = 0;
    reg [9:0]  peak_time    = 0;
    reg        peak_found   = 0;

    always @(posedge clk) begin
        if (rst) begin
            state         <= IDLE;
            feature_valid <= 0;
            sample_ctr    <= 0;
            cooldown_ctr  <= 0;
            width_ctr     <= 0;
            peak_time     <= 0;
            peak_found    <= 0;
            f1_width      <= 0;
            f2_timing     <= 0;
        end else begin
            feature_valid <= 0;

            case (state)

                IDLE: begin
                    if (spike_in) begin
                        state      <= CAPTURING;
                        sample_ctr <= 0;
                        width_ctr  <= 0;
                        peak_found <= 0;
                    end
                end

                CAPTURING: begin
                    sample_ctr <= sample_ctr + 1;

                    if (spike_in) begin
                        width_ctr <= width_ctr + 1;
                        if (!peak_found) begin
                            peak_time  <= sample_ctr;
                            peak_found <= 1;
                        end
                    end

                    if (sample_ctr == WINDOW_SIZE - 1) begin
                        // Normalize to Q8: multiply by 256, divide by WINDOW_SIZE
                        f1_width      <= (width_ctr * 256) / WINDOW_SIZE;
                        f2_timing     <= (peak_time  * 256) / WINDOW_SIZE;
                        feature_valid <= 1;
                        state         <= COOLDOWN;
                        cooldown_ctr  <= 0;
                    end
                end

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

endmodule
