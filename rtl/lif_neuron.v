// lif_neuron.v
// Discrete-time Leaky Integrate-and-Fire neuron.
//
// Each clock cycle:
//   if membrane >= THRESHOLD  ->  fire spike, membrane = 0
//   else                      ->  membrane = membrane - LEAK + weighted_in > 0

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
