// seg7_controller.v
// Drives the Basys-3 4-digit 7-segment display.
// Latches classification on result_valid pulse and displays:
//   nA → Neuron A
//   nb → Neuron B
//   no → Noise
//   -- → Idle

module seg7_controller (
    input  wire       clk,
    input  wire [1:0] classification,
    input  wire       result_valid,
    output reg  [6:0] seg,
    output wire [3:0] an
);

    // 7-segment encodings (active low, bit order: gfedcba)
    localparam SEG_n    = 7'b0101011;  // 'n'
    localparam SEG_A    = 7'b0001000;  // 'A'
    localparam SEG_b    = 7'b0000011;  // 'b'
    localparam SEG_o    = 7'b0100011;  // 'o'
    localparam SEG_DASH = 7'b0111111;  // '-'

    // Enable digits 1 and 0 only (rightmost two)
    assign an = 4'b1100;

    reg [1:0] display = 2'b11;

    // Latch on valid result pulse
    always @(posedge clk) begin
        if (result_valid)
            display <= classification;
    end

    // Combinational decode
    always @(*) begin
        case (display)
            2'b00:   seg = SEG_A;      // Neuron A
            2'b01:   seg = SEG_b;      // Neuron B
            2'b10:   seg = SEG_o;      // Noise
            default: seg = SEG_DASH;   // Idle / unknown
        endcase
    end

endmodule
