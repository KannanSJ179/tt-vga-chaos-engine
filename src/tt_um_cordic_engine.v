`default_nettype none
`timescale 1ns / 1ps

module tt_um_cordic_engine (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 1=output, 0=input)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

    wire       start    = uio_in[0];
    wire       out_sel  = uio_in[1]; 
    wire [7:0] theta_in = ui_in;
    
    wire [7:0] sin_out;
    wire [7:0] cos_out;
    wire       valid;

    // --- Instantiate the Core Engine ---
    cordic_engine u_engine (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (start),
        .theta_in (theta_in),
        .sin_out  (sin_out),
        .cos_out  (cos_out),
        .valid    (valid)
    );

    // --- Output Multiplexer ---
    assign uo_out = (out_sel) ? cos_out : sin_out;

    // --- Bidirectional IO Configuration ---
    assign uio_out[2]   = valid;
    assign uio_out[7:3] = 5'b0; // Tie off unused outputs
    assign uio_out[1:0] = 2'b0; // Tie off unused outputs

    // Output Enable: Bit 2 is Output (1), Bits 1:0 are Inputs (0)
    // Unused bits 7:3 set to input (0) to be safe.
    assign uio_oe = 8'b0000_0100;

    // --- Sink Unused Inputs to Prevent Verilator Lint Errors ---
    wire _unused = &{ena, uio_in[7:2], 1'b0};

endmodule
