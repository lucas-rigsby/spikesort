// snn_core.v
// Instantiates the full SNN: 2 inputs → 4 hidden LIF → 3 output LIF.
//
// IMPORTANT: Replace the placeholder localparam weight values below with
// the Q8 values printed by export/export_weights.py after training.
// The file export/weights_q8.vh contains the exact block to paste here.

module snn_core (
    input  wire       clk,
    input  wire       rst,
    input  wire [1:0] in_spike,    // rate-encoded input spikes
    output wire [2:0] out_spike    // [0]=NeuronA  [1]=NeuronB  [2]=Noise
);

    // ── PASTE Q8 WEIGHTS HERE (from export/weights_q8.vh) ─────────────────
    // W_IH: hidden layer  [4 neurons x 2 inputs]
    localparam signed [7:0] W_IH [0:3][0:1] = '{
        '{  87,  12 },   // H0
        '{ -23, 102 },   // H1
        '{  64, -44 },   // H2
        '{  31,  78 }    // H3
    };

    // W_HO: output layer  [3 neurons x 4 hidden]
    localparam signed [7:0] W_HO [0:2][0:3] = '{
        '{  95, -12,  33, -50 },  // O0 → Neuron A
        '{ -30,  88, -20,  61 },  // O1 → Neuron B
        '{  10,  15,  92,  22 }   // O2 → Noise
    };
    // ──────────────────────────────────────────────────────────────────────

    wire [3:0]          h_spike;
    wire signed [15:0]  weighted_h [0:3];
    wire signed [15:0]  weighted_o [0:2];

    // ── Hidden Layer (2 inputs → 4 LIF neurons) ───────────────────────────
    genvar h;
    generate
        for (h = 0; h < 4; h = h + 1) begin : hidden_layer
            assign weighted_h[h] =
                $signed({{8{W_IH[h][0][7]}}, W_IH[h][0]}) * $signed({7'b0, in_spike[0]}) +
                $signed({{8{W_IH[h][1][7]}}, W_IH[h][1]}) * $signed({7'b0, in_spike[1]});

            lif_neuron #(
                .THRESHOLD  (128),
                .LEAK       (2),
                .DATA_WIDTH (16)
            ) h_neuron (
                .clk         (clk),
                .rst         (rst),
                .weighted_in (weighted_h[h]),
                .spike_out   (h_spike[h])
            );
        end
    endgenerate

    // ── Output Layer (4 hidden → 3 LIF neurons) ───────────────────────────
    genvar o;
    generate
        for (o = 0; o < 3; o = o + 1) begin : output_layer
            assign weighted_o[o] =
                $signed({{8{W_HO[o][0][7]}}, W_HO[o][0]}) * $signed({7'b0, h_spike[0]}) +
                $signed({{8{W_HO[o][1][7]}}, W_HO[o][1]}) * $signed({7'b0, h_spike[1]}) +
                $signed({{8{W_HO[o][2][7]}}, W_HO[o][2]}) * $signed({7'b0, h_spike[2]}) +
                $signed({{8{W_HO[o][3][7]}}, W_HO[o][3]}) * $signed({7'b0, h_spike[3]});

            lif_neuron #(
                .THRESHOLD  (128),
                .LEAK       (2),
                .DATA_WIDTH (16)
            ) o_neuron (
                .clk         (clk),
                .rst         (rst),
                .weighted_in (weighted_o[o]),
                .spike_out   (out_spike[o])
            );
        end
    endgenerate

endmodule
