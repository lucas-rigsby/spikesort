// lif_neuron.v
// Leaky Integrate-and-Fire (LIF) neuron — core primitive of the SNN.
//
// Behaviour each clock cycle:
//   1. If membrane >= THRESHOLD  → fire spike, reset membrane to 0
//   2. Otherwise                 → membrane = membrane - LEAK + weighted_in
//   3. Clamp membrane at 0 (no sub-zero potential)
//
// Parameters:
//   THRESHOLD  — membrane voltage required to fire (default 128)
//   LEAK       — constant subtracted each cycle (default 2)
//   DATA_WIDTH — bit width of membrane register (default 16)

module lif_neuron #(
    parameter THRESHOLD  = 128,
    parameter LEAK       = 2,
    parameter DATA_WIDTH = 16
)(
    input  wire                         clk,
    input  wire                         rst,
    input  wire signed [DATA_WIDTH-1:0] weighted_in,
    output reg                          spike_out
);

    reg signed [DATA_WIDTH-1:0] membrane = 0;

    always @(posedge clk) begin
        if (rst) begin
            membrane  <= 0;
            spike_out <= 0;
        end else begin
            if (membrane >= $signed(THRESHOLD)) begin
                // Fire and hard reset
                spike_out <= 1;
                membrane  <= 0;
            end else begin
                spike_out <= 0;
                // Leak, integrate, clamp
                if (membrane > $signed(LEAK))
                    membrane <= membrane - $signed(LEAK) + weighted_in;
                else
                    membrane <= 0;
            end
        end
    end

endmodule
