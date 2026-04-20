// snn_core.v
// 3-input -> 6-hidden -> 3-output LIF spiking neural network.
//
// in_spike[2:0]: rate-encoded binary spike trains for F1, F2, F3
// out_spike[2:0]: [0]=Neuron A  [1]=Neuron B  [2]=Noise
//
// Weights are Q8 signed 8-bit integers (float * 128, clipped to [-128,127]).
// Replace placeholder values below with output of: python export/export_weights.py
//
// Individual localparam scalars are used instead of 2D arrays for
// Verilog-2001 compatibility — no SystemVerilog language mode required.

module snn_core (
    input  wire       clk,
    input  wire       rst,
    input  wire [2:0] in_spike,
    output wire [2:0] out_spike
);

    // ── PASTE Q8 WEIGHTS HERE (from export/export_weights.py) ────────────
     // Hidden layer weights: WH_<neuron>_<input>
    localparam signed [7:0] WH_0_0 =  -54;  localparam signed [7:0] WH_0_1 =  -18;  localparam signed [7:0] WH_0_2 =   32;
    localparam signed [7:0] WH_1_0 =  -21;  localparam signed [7:0] WH_1_1 =   22;  localparam signed [7:0] WH_1_2 =  -46;
    localparam signed [7:0] WH_2_0 =   15;  localparam signed [7:0] WH_2_1 =    1;  localparam signed [7:0] WH_2_2 =   50;
    localparam signed [7:0] WH_3_0 =  -40;  localparam signed [7:0] WH_3_1 =    2;  localparam signed [7:0] WH_3_2 =   88;
    localparam signed [7:0] WH_4_0 =   79;  localparam signed [7:0] WH_4_1 =   72;  localparam signed [7:0] WH_4_2 =  -16;
    localparam signed [7:0] WH_5_0 =   41;  localparam signed [7:0] WH_5_1 =   94;  localparam signed [7:0] WH_5_2 =   -1;

    // Output layer weights: WO_<neuron>_<hidden>
    localparam signed [7:0] WO_0_0 =  -27;  localparam signed [7:0] WO_0_1 =    7;  localparam signed [7:0] WO_0_2 =   -5;  localparam signed [7:0] WO_0_3 =  -91;  localparam signed [7:0] WO_0_4 =  106;  localparam signed [7:0] WO_0_5 = -128;
    localparam signed [7:0] WO_1_0 =  -29;  localparam signed [7:0] WO_1_1 =   -1;  localparam signed [7:0] WO_1_2 =   16;  localparam signed [7:0] WO_1_3 =  -39;  localparam signed [7:0] WO_1_4 =   17;  localparam signed [7:0] WO_1_5 =   -3;
    localparam signed [7:0] WO_2_0 =  -20;  localparam signed [7:0] WO_2_1 =  -11;  localparam signed [7:0] WO_2_2 =   13;  localparam signed [7:0] WO_2_3 =   68;  localparam signed [7:0] WO_2_4 =    3;  localparam signed [7:0] WO_2_5 =   10;
    // ── END WEIGHTS ───────────────────────────────────────────────────────

    // ── Hidden layer weighted sums ────────────────────────────────────────
    wire signed [15:0] wh0, wh1, wh2, wh3, wh4, wh5;

    assign wh0 = $signed({{8{WH_0_0[7]}},WH_0_0}) * $signed({7'b0,in_spike[0]})
               + $signed({{8{WH_0_1[7]}},WH_0_1}) * $signed({7'b0,in_spike[1]})
               + $signed({{8{WH_0_2[7]}},WH_0_2}) * $signed({7'b0,in_spike[2]});

    assign wh1 = $signed({{8{WH_1_0[7]}},WH_1_0}) * $signed({7'b0,in_spike[0]})
               + $signed({{8{WH_1_1[7]}},WH_1_1}) * $signed({7'b0,in_spike[1]})
               + $signed({{8{WH_1_2[7]}},WH_1_2}) * $signed({7'b0,in_spike[2]});

    assign wh2 = $signed({{8{WH_2_0[7]}},WH_2_0}) * $signed({7'b0,in_spike[0]})
               + $signed({{8{WH_2_1[7]}},WH_2_1}) * $signed({7'b0,in_spike[1]})
               + $signed({{8{WH_2_2[7]}},WH_2_2}) * $signed({7'b0,in_spike[2]});

    assign wh3 = $signed({{8{WH_3_0[7]}},WH_3_0}) * $signed({7'b0,in_spike[0]})
               + $signed({{8{WH_3_1[7]}},WH_3_1}) * $signed({7'b0,in_spike[1]})
               + $signed({{8{WH_3_2[7]}},WH_3_2}) * $signed({7'b0,in_spike[2]});

    assign wh4 = $signed({{8{WH_4_0[7]}},WH_4_0}) * $signed({7'b0,in_spike[0]})
               + $signed({{8{WH_4_1[7]}},WH_4_1}) * $signed({7'b0,in_spike[1]})
               + $signed({{8{WH_4_2[7]}},WH_4_2}) * $signed({7'b0,in_spike[2]});

    assign wh5 = $signed({{8{WH_5_0[7]}},WH_5_0}) * $signed({7'b0,in_spike[0]})
               + $signed({{8{WH_5_1[7]}},WH_5_1}) * $signed({7'b0,in_spike[1]})
               + $signed({{8{WH_5_2[7]}},WH_5_2}) * $signed({7'b0,in_spike[2]});

    // ── Hidden layer: 6 LIF neurons ──────────────────────────────────────
    wire [5:0] h_spike;

    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) h0(.clk(clk),.rst(rst),.weighted_in(wh0),.spike_out(h_spike[0]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) h1(.clk(clk),.rst(rst),.weighted_in(wh1),.spike_out(h_spike[1]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) h2(.clk(clk),.rst(rst),.weighted_in(wh2),.spike_out(h_spike[2]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) h3(.clk(clk),.rst(rst),.weighted_in(wh3),.spike_out(h_spike[3]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) h4(.clk(clk),.rst(rst),.weighted_in(wh4),.spike_out(h_spike[4]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) h5(.clk(clk),.rst(rst),.weighted_in(wh5),.spike_out(h_spike[5]));

    // ── Output layer weighted sums ────────────────────────────────────────
    wire signed [15:0] wo0, wo1, wo2;

    assign wo0 = $signed({{8{WO_0_0[7]}},WO_0_0}) * $signed({7'b0,h_spike[0]})
               + $signed({{8{WO_0_1[7]}},WO_0_1}) * $signed({7'b0,h_spike[1]})
               + $signed({{8{WO_0_2[7]}},WO_0_2}) * $signed({7'b0,h_spike[2]})
               + $signed({{8{WO_0_3[7]}},WO_0_3}) * $signed({7'b0,h_spike[3]})
               + $signed({{8{WO_0_4[7]}},WO_0_4}) * $signed({7'b0,h_spike[4]})
               + $signed({{8{WO_0_5[7]}},WO_0_5}) * $signed({7'b0,h_spike[5]});

    assign wo1 = $signed({{8{WO_1_0[7]}},WO_1_0}) * $signed({7'b0,h_spike[0]})
               + $signed({{8{WO_1_1[7]}},WO_1_1}) * $signed({7'b0,h_spike[1]})
               + $signed({{8{WO_1_2[7]}},WO_1_2}) * $signed({7'b0,h_spike[2]})
               + $signed({{8{WO_1_3[7]}},WO_1_3}) * $signed({7'b0,h_spike[3]})
               + $signed({{8{WO_1_4[7]}},WO_1_4}) * $signed({7'b0,h_spike[4]})
               + $signed({{8{WO_1_5[7]}},WO_1_5}) * $signed({7'b0,h_spike[5]});

    assign wo2 = $signed({{8{WO_2_0[7]}},WO_2_0}) * $signed({7'b0,h_spike[0]})
               + $signed({{8{WO_2_1[7]}},WO_2_1}) * $signed({7'b0,h_spike[1]})
               + $signed({{8{WO_2_2[7]}},WO_2_2}) * $signed({7'b0,h_spike[2]})
               + $signed({{8{WO_2_3[7]}},WO_2_3}) * $signed({7'b0,h_spike[3]})
               + $signed({{8{WO_2_4[7]}},WO_2_4}) * $signed({7'b0,h_spike[4]})
               + $signed({{8{WO_2_5[7]}},WO_2_5}) * $signed({7'b0,h_spike[5]});

    // ── Output layer: 3 LIF neurons ──────────────────────────────────────
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) o0(.clk(clk),.rst(rst),.weighted_in(wo0),.spike_out(out_spike[0]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) o1(.clk(clk),.rst(rst),.weighted_in(wo1),.spike_out(out_spike[1]));
    lif_neuron #(.THRESHOLD(128),.LEAK(2),.DATA_WIDTH(16)) o2(.clk(clk),.rst(rst),.weighted_in(wo2),.spike_out(out_spike[2]));

endmodule
