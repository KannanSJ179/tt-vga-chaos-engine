`timescale 1ns / 1ps

module cordic_core_stage (
    input  wire signed [15:0] x_in,      // Current X value
    input  wire signed [15:0] y_in,      // Current Y value
    input  wire signed [15:0] z_in,      // Current residual angle Z
    input  wire        [3:0]  iter,      // Iteration index 'i' (0 to 15)
    input  wire signed [15:0] lut_val,   // arctan(2^-i) from ROM

    output wire signed [15:0] x_next,    // Next X value
    output wire signed [15:0] y_next,    // Next Y value
    output wire signed [15:0] z_next     // Next residual angle Z
);

    // 1. Determine rotation direction (d)
    wire is_z_neg = z_in[15]; 

    // 2. Perform Arithmetic Right Shifts
    wire signed [15:0] x_shifted = x_in >>> iter;
    wire signed [15:0] y_shifted = y_in >>> iter;

    // 3. Shift-and-Add Datapath & Angle Accumulator
    assign x_next = is_z_neg ? (x_in + y_shifted) : (x_in - y_shifted);
    assign y_next = is_z_neg ? (y_in - x_shifted) : (y_in + x_shifted);
    assign z_next = is_z_neg ? (z_in + lut_val)   : (z_in - lut_val);

endmodule
