// xadc_sampler.v
// Artix-7 XADC, single channel continuous mode on VAUXP[0]/VAUXN[0].
// Physical pins: J3 (VP, signal 0-1V) and K3 (VN, GND reference).


module xadc_sampler (
    input  wire        clk,
    input  wire        rst,
    output reg  [11:0] sample,
    output reg         sample_valid
);

    wire [15:0] do_out;
    wire        drdy_out;
    wire        eoc_out;
    wire        eos_out, busy_out;
    wire [4:0]  channel_out, muxaddr_out;
    wire [7:0]  alm_out;
    wire        ot_out, jtagbusy_out, jtaglocked_out, jtagmodified_out;

    XADC #(
        .INIT_40 (16'h9000),   // single channel, aux enabled, no averaging
        .INIT_41 (16'h3010),   // SEQ=0011 single channel, CH=10000 VAUX0
        .INIT_42 (16'h0400),   // divider=4 -> 25MHz ADC -> ~960 KSPS
        .INIT_43 (16'h0000), .INIT_44 (16'h0000),
        .INIT_45 (16'h0000), .INIT_46 (16'h0000), .INIT_47 (16'h0000),
        .INIT_48 (16'h0001),   // sequencer: bit[0]=VAUX0 enabled
        .INIT_49 (16'h0000), .INIT_4A (16'h0000), .INIT_4B (16'h0000),
        .INIT_4C (16'h0000), .INIT_4D (16'h0000), .INIT_4E (16'h0000),
        .INIT_4F (16'h0000),
        .INIT_50 (16'hB5ED), .INIT_51 (16'h57E4),
        .INIT_52 (16'hA147), .INIT_53 (16'hCA33),
        .INIT_54 (16'hA93A), .INIT_55 (16'h52C6),
        .INIT_56 (16'h9555), .INIT_57 (16'hAE4E),
        .INIT_58 (16'h5999), .INIT_5C (16'h5111),
        .SIM_MONITOR_FILE ("design.txt")
    ) xadc_inst (
        .DCLK(clk), .RESET(rst),
        .VAUXP(16'b0000000000000001), .VAUXN(16'b0000000000000000),
        .VP(1'b0), .VN(1'b0),
        .DADDR(7'h10), .DEN(eoc_out), .DWE(1'b0),
        .DI(16'h0000), .DO(do_out), .DRDY(drdy_out),
        .CONVST(1'b0), .CONVSTCLK(1'b0),
        .EOC(eoc_out), .EOS(eos_out), .BUSY(busy_out),
        .CHANNEL(channel_out), .ALM(alm_out), .OT(ot_out),
        .JTAGBUSY(jtagbusy_out), .JTAGLOCKED(jtaglocked_out),
        .JTAGMODIFIED(jtagmodified_out), .MUXADDR(muxaddr_out)
    );

    always @(posedge clk) begin
        if (rst) begin
            sample       <= 12'h000;
            sample_valid <= 1'b0;
        end else begin
            sample_valid <= 1'b0;
            if (drdy_out) begin
                sample       <= do_out[15:4];
                sample_valid <= 1'b1;
            end
        end
    end

endmodule
