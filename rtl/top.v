// ============================================================================
// top -- board template top-level (blink LED example)
//
// Verification goal: 25MHz crystal input works, LED outputs work
// (board LED D2 and the expansion LEDs).
// Use this file as the top-level for future designs; replace internals only.
// ============================================================================
`timescale 1ns / 1ps

module top (
    input  wire        i_clk_25m,   // 25MHz crystal (K4)
    output wire [3:0]  o_led,       // expansion LEDs (N14/P15/P16/R16, from official example)
    output wire        o_led_board  // board LED D2 (A18)
);

    // No external reset on board; tie high (add key/power-on reset if needed)
    wire rst_n = 1'b1;

    blink #(
        .CLK_FREQ_HZ (25_000_000),  // input clock frequency
        .BLINK_HZ    (4)            // blink rate in Hz (visible to eye)
    ) u_blink (
        .clk       (i_clk_25m),
        .rst_n     (rst_n),
        .led       (o_led),
        .led_board (o_led_board)
    );

endmodule
