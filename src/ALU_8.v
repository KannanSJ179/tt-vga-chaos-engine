`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.03.2026 08:28:36
// Design Name: 
// Module Name: ALU_8
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


module ALU_8(
input [7:0]A, [7:0]B,
input [2:0]alu_op,
output reg[7:0]result

);
parameter[2:0]ADD = 3'b000, SUB = 3'b001, AND = 3'b010, OR = 3'b011, NOT = 3'b100, MOV = 3'b101; 
always@(*) begin
case(alu_op)
ADD:result = A+B;
SUB:result = A-B;
AND:result = A&B;
OR:result = A|B;
NOT:result = (~B);
MOV:result = B;
default:result = A;
endcase
end
endmodule
