// input_sync.v
// Two flip-flop synchronizer to resolve metastability on async GPIO input.
// The ASYNC_REG attribute tells Vivado to place both FFs close together.

module input_sync (
    input  wire clk,
    input  wire async_in,
    output wire sync_out
);

    (* ASYNC_REG = "TRUE" *) reg stage1 = 0;
    (* ASYNC_REG = "TRUE" *) reg stage2 = 0;

    always @(posedge clk) begin
        stage1 <= async_in;
        stage2 <= stage1;
    end

    assign sync_out = stage2;

endmodule
