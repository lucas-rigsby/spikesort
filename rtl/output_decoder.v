// output_decoder.v
// ──────────────────────────────────────────────────────────────────────────────
// Accumulates SNN output spike counts over a fixed voting window, then
// performs argmax to determine the winning classification.
//
// Classification codes:
//   2'b00 = Neuron A (fast-spiking interneuron)
//   2'b01 = Neuron B (regular-spiking pyramidal cell)
//   2'b10 = Noise
//   2'b11 = Idle / unclassified (startup state)
//
// Neuron A wins on ties (hardcoded priority in if-else chain).
// VOTE_WINDOW = 256 cycles gives each output neuron up to 256 spike
// opportunities — enough for reliable argmax separation.

module output_decoder #(
    parameter VOTE_WINDOW = 256
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] out_spike,      // from snn_core: [0]=A [1]=B [2]=N
    output reg  [1:0] classification, // 2-bit class code
    output reg        result_valid    // one-cycle strobe on window boundary
);

    // 8-bit counters sufficient: max count = VOTE_WINDOW = 256 = 8'hFF
    reg [7:0] count_A   = 0;
    reg [7:0] count_B   = 0;
    reg [7:0] count_N   = 0;
    reg [7:0] vote_ctr  = 0;

    always @(posedge clk) begin
        if (rst) begin
            count_A        <= 0;
            count_B        <= 0;
            count_N        <= 0;
            vote_ctr       <= 0;
            result_valid   <= 1'b0;
            classification <= 2'b11;  // idle
        end else begin
            result_valid <= 1'b0;

            // Accumulate output neuron spikes
            if (out_spike[0]) count_A <= count_A + 1;
            if (out_spike[1]) count_B <= count_B + 1;
            if (out_spike[2]) count_N <= count_N + 1;

            vote_ctr <= vote_ctr + 1;

            // Window boundary: classify and reset
            if (vote_ctr == VOTE_WINDOW - 1) begin
                result_valid <= 1'b1;
                vote_ctr     <= 0;

                // Argmax — Neuron A wins ties
                if      (count_A >= count_B && count_A >= count_N)
                    classification <= 2'b00;  // Neuron A
                else if (count_B >= count_A && count_B >= count_N)
                    classification <= 2'b01;  // Neuron B
                else
                    classification <= 2'b10;  // Noise

                // Reset counters for next window
                count_A <= 0;
                count_B <= 0;
                count_N <= 0;
            end
        end
    end

endmodule
