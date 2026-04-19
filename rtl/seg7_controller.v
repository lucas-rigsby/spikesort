// seg7_controller.v
// Drives rightmost digit of Basys-3 7-segment display.
// Latches classification on result_valid, holds until next spike.
//
// Characters (active low, gfedcba):
//   'A' = 0001000    'b' = 0000011    'N' = 0001001    '-' = 0111111
//
// (* keep = "true" *) on display register prevents Vivado from optimising
// away the register during synthesis and reporting constant-driven port
// warnings on seg and an.

module seg7_controller (
    input  wire       clk,
    input  wire [1:0] classification,
    input  wire       result_valid,
    output reg  [6:0] seg,
    output wire [3:0] an
);

    localparam SEG_A    = 7'b0001000;
    localparam SEG_b    = 7'b0000011;
    localparam SEG_N    = 7'b0001001;
    localparam SEG_DASH = 7'b0111111;

    // Rightmost digit permanently active (active low: 0 = on)
    assign an = 4'b1110;

    (* keep = "true" *) reg [1:0] display = 2'b11;

    always @(posedge clk) begin
        if (result_valid)
            display <= classification;
    end

    always @(*) begin
        case (display)
            2'b00:   seg = SEG_A;
            2'b01:   seg = SEG_b;
            2'b10:   seg = SEG_N;
            default: seg = SEG_DASH;
        endcase
    end

endmodule
