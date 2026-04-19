// lif_neuron.v
// Discrete-time Leaky Integrate-and-Fire neuron — reusable primitive.
//
// Each clock cycle:
//   if membrane >= THRESHOLD  ->  fire spike, membrane = 0  (hard reset)
//   else                      ->  membrane = membrane - LEAK + weighted_in
//                                 (clamped at 0)
//
// THRESHOLD = 128, LEAK = 2, DATA_WIDTH = 16 bits.
// Weights are signed 8-bit Q8 integers passed in pre-multiplied from snn_core.
// Since inputs are binary (0 or 1) the multiply is a conditional add —
// Vivado synthesises this as LUT arithmetic, consuming zero DSP blocks.

module lif_neuron #(
    parameter THRESHOLD  = 128,
    parameter LEAK       = 2,
    parameter DATA_WIDTH = 16
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire signed [DATA_WIDTH-1:0]  weighted_in,
    output reg                           spike_out
);

    reg signed [DATA_WIDTH-1:0] membrane = 0;

    always @(posedge clk) begin
        if (rst) begin
            membrane  <= 0;
            spike_out <= 1'b0;
        end else begin
            if (membrane >= $signed(THRESHOLD)) begin
                spike_out <= 1'b1;
                membrane  <= 0;
            end else begin
                spike_out <= 1'b0;
                if (membrane > $signed(LEAK))
                    membrane <= membrane - $signed(LEAK) + weighted_in;
                else
                    membrane <= (weighted_in > 0) ? weighted_in : 0;
            end
        end
    end

endmodule
