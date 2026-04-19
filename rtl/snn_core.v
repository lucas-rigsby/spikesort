// snn_core.v
// ──────────────────────────────────────────────────────────────────────────────
// Full two-layer LIF spiking neural network: 3 inputs → 6 hidden → 3 outputs.
//
// Inputs  (in_spike[2:0]):  rate-encoded binary spike trains for F1, F2, F3
// Outputs (out_spike[2:0]): [0]=Neuron A  [1]=Neuron B  [2]=Noise
//
// Weights are Q8 signed 8-bit integers (float × 128, clipped to [-128,127]).
// Run export/export_weights.py after training to generate the correct values
// and paste them between the markers below.
//
// Weighted input computation per neuron h:
//   weighted_h[h] = Σ_{i=0}^{2}  W_IH[h][i] × in_spike[i]
//
// Since in_spike[i] is binary (0 or 1), this is a conditional sum —
// W_IH[h][i] is added only when input neuron i fires that cycle.
// Vivado synthesizes this as LUT-based adders, consuming zero DSP blocks.

module snn_core (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] in_spike,     // [0]=F1  [1]=F2  [2]=F3 (rate-encoded)
    output wire [2:0] out_spike     // [0]=A   [1]=B   [2]=N
);

    // ── PASTE EXPORTED Q8 WEIGHTS HERE ────────────────────────────────────────
    // Replace the placeholder values below with the output of:
    //   python export/export_weights.py
    // The file export/weights_q8.vh contains the exact block to paste.

    // W_IH [6 hidden × 3 inputs]
    localparam signed [7:0] W_IH [0:5][0:2] = '{
        '{  -54,  -18,   32 },   // H0
        '{  -21,   22,  -46 },   // H1
        '{   15,    1,   50 },   // H2
        '{  -40,    2,   88 },   // H3
        '{   79,   72,  -16 },   // H4
        '{   41,   94,   -1 }   // H5
    };

    // W_HO [3 outputs × 6 hidden]
    localparam signed [7:0] W_HO [0:2][0:5] = '{
        '{  -27,    7,   -5,  -91,  106, -128 },   // O0
        '{  -29,   -1,   16,  -39,   17,   -3 },   // O1
        '{  -20,  -11,   13,   68,    3,   10 }   // O2
    };
    // ── END WEIGHTS ───────────────────────────────────────────────────────────

    wire [5:0]         h_spike;
    wire signed [15:0] weighted_h [0:5];
    wire signed [15:0] weighted_o [0:2];

    // ── Hidden layer: 3 inputs → 6 LIF neurons ────────────────────────────────
    genvar h;
    generate
        for (h = 0; h < 6; h = h + 1) begin : hidden_layer

            // Sign-extend 8-bit weights to 16 bits before multiply
            // in_spike[i] is 1-bit binary so multiply = conditional add
            assign weighted_h[h] =
                $signed({{8{W_IH[h][0][7]}}, W_IH[h][0]}) * $signed({7'b0, in_spike[0]}) +
                $signed({{8{W_IH[h][1][7]}}, W_IH[h][1]}) * $signed({7'b0, in_spike[1]}) +
                $signed({{8{W_IH[h][2][7]}}, W_IH[h][2]}) * $signed({7'b0, in_spike[2]});

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

    // ── Output layer: 6 hidden → 3 LIF neurons ────────────────────────────────
    genvar o;
    generate
        for (o = 0; o < 3; o = o + 1) begin : output_layer

            assign weighted_o[o] =
                $signed({{8{W_HO[o][0][7]}}, W_HO[o][0]}) * $signed({7'b0, h_spike[0]}) +
                $signed({{8{W_HO[o][1][7]}}, W_HO[o][1]}) * $signed({7'b0, h_spike[1]}) +
                $signed({{8{W_HO[o][2][7]}}, W_HO[o][2]}) * $signed({7'b0, h_spike[2]}) +
                $signed({{8{W_HO[o][3][7]}}, W_HO[o][3]}) * $signed({7'b0, h_spike[3]}) +
                $signed({{8{W_HO[o][4][7]}}, W_HO[o][4]}) * $signed({7'b0, h_spike[4]}) +
                $signed({{8{W_HO[o][5][7]}}, W_HO[o][5]}) * $signed({7'b0, h_spike[5]});

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
