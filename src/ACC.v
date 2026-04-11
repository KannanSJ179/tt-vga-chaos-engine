`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.03.2026 10:30:18
// Design Name: 
// Module Name: ACC
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////



module ACC(
    input clk,
    input reset,
    input load,
    input [7:0] data_in,
    output reg [7:0] data_out
);

always @(posedge clk or posedge reset) begin
    if (reset)
        data_out <= 8'b00000000;
    else if (load)
        data_out <= data_in;
    else
        data_out <= data_out;
end

endmodule
