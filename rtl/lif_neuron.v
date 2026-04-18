// lif_neuron.v
// ──────────────────────────────────────────────────────────────────────────────
// Discrete-time Leaky Integrate-and-Fire (LIF) neuron — reusable primitive.
//
// Update rule each clock cycle:
//   if membrane >= THRESHOLD:
//       fire spike,  membrane = 0  (hard reset)
//   else:
//       membrane = membrane - LEAK + weighted_in  (clamp at 0)
//
// The LEAK term implements exponential membrane decay between events,
// approximating the continuous-time equation V(t) = V_0 × e^(−t/τ)
// where τ = 1/LEAK in discrete time.
//
// Parameters:
//   THRESHOLD  — membrane potential required to fire (default 128)
//   LEAK       — constant subtracted each cycle (default 2)
//   DATA_WIDTH — membrane register bit width (default 16)
//
// Synaptic weights are signed 8-bit Q8 integers. Since inputs are binary
// (0 or 1), the multiply reduces to a conditional add synthesized as
// LUT-based adder arithmetic — no DSP blocks consumed.

module lif_neuron #(
    parameter THRESHOLD  = 128,
    parameter LEAK       = 2,
    parameter DATA_WIDTH = 16
)(
    input  wire                          clk,
    input  wire                          rst,
    input  wire signed [DATA_WIDTH-1:0]  weighted_in,  // pre-summed weighted input
    output reg                           spike_out
);

    reg signed [DATA_WIDTH-1:0] membrane = 0;

    always @(posedge clk) begin
        if (rst) begin
            membrane  <= 0;
            spike_out <= 1'b0;
        end else begin
            if (membrane >= $signed(THRESHOLD)) begin
                // ── Fire and hard reset ──────────────────────────────────────
                spike_out <= 1'b1;
                membrane  <= 0;
            end else begin
                spike_out <= 1'b0;
                // ── Leak, integrate, clamp at zero ───────────────────────────
                // Check before subtracting LEAK to prevent underflow toward
                // large negative values when membrane is near zero.
                if (membrane > $signed(LEAK))
                    membrane <= membrane - $signed(LEAK) + weighted_in;
                else
                    membrane <= (weighted_in > 0) ? weighted_in : 0;
            end
        end
    end

endmodule
