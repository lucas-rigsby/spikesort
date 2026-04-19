// spike_detector.v
// Three-state FSM: IDLE -> CAPTURING -> COOLDOWN.
// Runs at 1 MHz (clk = clk_1mhz from spike_sorter_top).
// sample_valid is the stretched version from the top-level CDC logic.
//
// Features extracted (Q8 normalised: value * 256 / WINDOW_SIZE):
//   F1 — spike width   : samples above threshold / WINDOW_SIZE
//   F2 — peak timing   : index of maximum sample / WINDOW_SIZE
//   F3 — rise ratio    : above-threshold samples before peak / total above threshold
//
// Timing at 1 MHz:
//   WINDOW_SIZE = 1000 -> 1 ms capture window
//   REFRACTORY  = 10000 -> 10 ms refractory period
//   Total       = 11 ms  <<  500 ms ISI of Neuron A

module spike_detector #(
    parameter WINDOW_SIZE       = 1000,
    parameter REFRACTORY_CYCLES = 10000,
    parameter THRESHOLD         = 200     // 200/4095 * 1V = 49 mV
)(
    input  wire        clk,
    input  wire        rst,
    input  wire [11:0] sample,
    input  wire        sample_valid,   // stretched CDC pulse from top
    output reg         feature_valid,  // one-cycle strobe at 1 MHz
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

            if (sample_valid) begin
                case (state)

                    IDLE: begin
                        if (sample > THRESHOLD) begin
                            state      <= CAPTURING;
                            sample_ctr <= 0;
                            width_ctr  <= 1;
                            rise_ctr   <= 0;
                            peak_idx   <= 0;
                            peak_val   <= sample;
                            peaked     <= 1'b0;
                        end
                    end

                    CAPTURING: begin
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
                            f1_width      <= (width_ctr * 256) / WINDOW_SIZE;
                            f2_timing     <= (peak_idx  * 256) / WINDOW_SIZE;
                            f3_ratio      <= (width_ctr > 0) ?
                                             (rise_ctr  * 256) / width_ctr :
                                             8'h00;
                            feature_valid <= 1'b1;
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
    end

endmodule
