// output_decoder.v
// Accumulates SNN output spike counts over VOTE_WINDOW cycles.
// spike_active gates accumulation — only runs during real spike events.
// This prevents noise from producing spurious classifications and keeps
// the display on '-' when no signal is present.
//
// Classification codes:
//   2'b00 = Neuron A   2'b01 = Neuron B   2'b10 = Noise   2'b11 = Idle

module output_decoder #(
    parameter VOTE_WINDOW = 256
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] out_spike,
    input  wire       spike_active,    // high for 256 cycles after each spike
    output reg  [1:0] classification,
    output reg        result_valid
);

    reg [7:0] count_A  = 0;
    reg [7:0] count_B  = 0;
    reg [7:0] count_N  = 0;
    reg [7:0] vote_ctr = 0;

    always @(posedge clk) begin
        if (rst) begin
            count_A        <= 0;
            count_B        <= 0;
            count_N        <= 0;
            vote_ctr       <= 0;
            result_valid   <= 1'b0;
            classification <= 2'b11;
        end else begin
            result_valid <= 1'b0;

            if (spike_active) begin
                if (out_spike[0]) count_A <= count_A + 1;
                if (out_spike[1]) count_B <= count_B + 1;
                if (out_spike[2]) count_N <= count_N + 1;

                vote_ctr <= vote_ctr + 1;

                if (vote_ctr == VOTE_WINDOW - 1) begin
                    result_valid <= 1'b1;
                    vote_ctr     <= 0;

                    if      (count_A >= count_B && count_A >= count_N)
                        classification <= 2'b00;
                    else if (count_B >= count_A && count_B >= count_N)
                        classification <= 2'b01;
                    else
                        classification <= 2'b10;

                    count_A <= 0;
                    count_B <= 0;
                    count_N <= 0;
                end
            end else begin
                vote_ctr <= 0;
            end
        end
    end

endmodule
