`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.03.2026 09:48:14
// Design Name: 
// Module Name: Decoder
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


module Decoder(
input [7:0]instr,
output reg [2:0]alu_op,
output reg acc_load,mem_write,
output [7:0]operand_out);
wire [3:0]opcode;
assign opcode  = instr[7:5];
assign operand_out = {3'b000,instr[4:0]};
parameter[2:0]LOAD = 3'b110, STORE= 3'b111;
always@(*) begin
if(opcode==STORE)begin
alu_op = STORE;
acc_load = 0;
mem_write = 1;
end
else if(opcode==LOAD)begin
alu_op   = LOAD;
acc_load = 1;
mem_write = 0;
end
else begin
alu_op   = opcode;
acc_load = 1;
mem_write = 0;
end
end
endmodule
