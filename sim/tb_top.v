// ============================================================================
// tb_top -- top-level testbench
// Checks: clock generation + blink state transitions
// Timing: with BLINK_HZ=4, led shifts every 125ms; this tb runs 310ms.
// ============================================================================
`timescale 1ns / 1ps

module tb_top;

    reg        i_clk_25m = 1'b0;
    wire [3:0] o_led;
    wire       o_led_board;

    // 25MHz clock: 40ns period
    always #20 i_clk_25m = ~i_clk_25m;

    top u_top (
        .i_clk_25m   (i_clk_25m),
        .o_led       (o_led),
        .o_led_board (o_led_board)
    );

    initial begin
        $dumpfile("tb_top.vcd");
        $dumpvars(0, tb_top);

        // Check initial state after a few cycles
        #100;
        if (o_led !== 4'b0001 || o_led_board !== 1'b0) begin
            $display("FAIL: initial state led=%b led_board=%b", o_led, o_led_board);
            $finish;
        end

        // At 300ms: led shifted twice (0001->0010->0100 at 125/250ms),
        // led_board toggled twice (1 at 125ms, 0 at 250ms)
        #300_000_000;
        if (o_led === 4'b0100 && o_led_board === 1'b0) begin
            $display("PASS: blink works led=%b led_board=%b", o_led, o_led_board);
        end else begin
            $display("FAIL: state at 300ms led=%b led_board=%b", o_led, o_led_board);
        end
        $finish;
    end

endmodule
