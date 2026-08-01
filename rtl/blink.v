// ============================================================================
// blink -- clock divider + LED blink example module
//
// Behavior: toggles state every CLK_FREQ_HZ/(BLINK_HZ*2) clock cycles
//   - led[3:0]      rotating pattern (left shift)
//   - led_board     square-wave blink
// ============================================================================
`timescale 1ns / 1ps

module blink #(
    parameter CLK_FREQ_HZ = 25_000_000,
    parameter BLINK_HZ    = 4
) (
    input  wire       clk,
    input  wire       rst_n,
    output reg  [3:0] led      = 4'b0001,
    output reg        led_board = 1'b0
);

    localparam integer CNT_MAX = (CLK_FREQ_HZ / (BLINK_HZ * 2)) - 1;

    reg [31:0] cnt = 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cnt       <= 0;
            led       <= 4'b0001;
            led_board <= 1'b0;
        end else if (cnt >= CNT_MAX) begin
            cnt       <= 0;
            led       <= {led[2:0], led[3]};   // rotate left
            led_board <= ~led_board;
        end else begin
            cnt <= cnt + 1;
        end
    end

endmodule
