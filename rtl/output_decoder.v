// output_decoder.v
// Accumulates output spike counts over a fixed voting window, then
// performs an argmax to determine the winning class.
// Classification codes: 00 = Neuron A,  01 = Neuron B,  10 = Noise

module output_decoder #(
    parameter VOTE_WINDOW = 256
)(
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] out_spike,
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
            result_valid   <= 0;
            classification <= 2'b11;  // idle
        end else begin
            result_valid <= 0;

            // Accumulate spikes from each output neuron
            if (out_spike[0]) count_A <= count_A + 1;
            if (out_spike[1]) count_B <= count_B + 1;
            if (out_spike[2]) count_N <= count_N + 1;

            vote_ctr <= vote_ctr + 1;

            if (vote_ctr == VOTE_WINDOW - 1) begin
                result_valid <= 1;
                vote_ctr     <= 0;

                // Argmax — Neuron A wins ties
                if      (count_A >= count_B && count_A >= count_N)
                    classification <= 2'b00;
                else if (count_B >= count_A && count_B >= count_N)
                    classification <= 2'b01;
                else
                    classification <= 2'b10;

                // Reset accumulators for next window
                count_A <= 0;
                count_B <= 0;
                count_N <= 0;
            end
        end
    end

endmodule
