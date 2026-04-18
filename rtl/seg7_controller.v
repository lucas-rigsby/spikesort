// seg7_controller.v
// ──────────────────────────────────────────────────────────────────────────────
// Drives the rightmost digit of the Basys-3 four-digit seven-segment display.
// Latches classification on result_valid and holds indefinitely until next
// valid result. Startup state displays '-' (idle).
//
// 7-segment bit order: gfedcba (active low)
//
//   Display  |  Segments ON        |  Pattern (gfedcba)
//   ---------+--------------------+-----------------
//   'A'      |  a,b,c,e,f,g        |  0001000
//   'b'      |  c,d,e,f,g          |  0000011
//   'N'      |  a,b,c,e,f          |  0001001
//   '-'      |  g                  |  0111111
//
// anode assignment: 4'b1110 = rightmost digit active, others off.

module seg7_controller (
    input  wire       clk,
    input  wire [1:0] classification,  // 00=A  01=B  10=N  11=idle
    input  wire       result_valid,    // one-cycle latch strobe
    output reg  [6:0] seg,             // active-low segment drive (gfedcba)
    output wire [3:0] an               // active-low anode select
);

    // Segment encodings — active low, bit order gfedcba
    localparam SEG_A    = 7'b0001000;  // 'A'
    localparam SEG_b    = 7'b0000011;  // 'b'
    localparam SEG_N    = 7'b0001001;  // 'N'
    localparam SEG_DASH = 7'b0111111;  // '-' (idle / startup)

    // Enable rightmost digit only (active low — 0 = on, 1 = off)
    assign an = 4'b1110;

    // Latched classification — holds last valid result between spikes
    reg [1:0] display = 2'b11;  // startup: idle

    // Latch on result_valid pulse
    always @(posedge clk) begin
        if (result_valid)
            display <= classification;
    end

    // Combinational segment decode
    always @(*) begin
        case (display)
            2'b00:   seg = SEG_A;     // Neuron A — interneuron
            2'b01:   seg = SEG_b;     // Neuron B — pyramidal cell
            2'b10:   seg = SEG_N;     // Noise
            default: seg = SEG_DASH;  // Idle / startup
        endcase
    end

endmodule
