`default_nettype none
`timescale 1ns / 1ps

module tb ();

    // --- Dump signals for the automated waveform viewer ---
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
        #1;
    end

    // --- Signals for Tiny Tapeout Wrapper ---
    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    reg        ena;
    reg        clk;
    reg        rst_n;
    
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // --- GATE LEVEL POWER PINS (THE FIX) ---
    // These are absolutely critical for physical silicon simulation!
    `ifdef GL_TEST
        wire VPWR = 1'b1;
        wire VGND = 1'b0;
    `endif

    // --- Device Under Test (DUT) ---
    tt_um_cordic_engine user_project (
    `ifdef GL_TEST
        .VPWR(VPWR),
        .VGND(VGND),
    `endif
        .ui_in   (ui_in),
        .uo_out  (uo_out),
        .uio_in  (uio_in),
        .uio_out (uio_out),
        .uio_oe  (uio_oe),
        .ena     (ena),
        .clk     (clk),
        .rst_n   (rst_n)
    );

endmodule
