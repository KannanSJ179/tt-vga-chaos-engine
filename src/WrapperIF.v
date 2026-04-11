`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.03.2026 11:01:06
// Design Name: 
// Module Name: WrapperIF
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


module fetch_stage(
input reset,clk,
output reg [7:0] PC_out);
always@ (posedge clk)
begin
if(reset)
PC_out <=8'b0;
else
PC_out<=PC_out + 1;
end
endmodule

module pipeline_register(
input clk,reset,
input [7:0]instr_in,
output reg[7:0] instr_out );
always@(posedge clk)
begin
if(reset)
instr_out<=8'b0;
else
instr_out<=instr_in;
end
endmodule

module instruction_register (
    input   clk,
    input   reset,
    input  [7:0] Instruction,   
    output reg  [7:0] instr_out);

always @(posedge clk ) begin
    if (reset)
        instr_out <= 8'd0;
    else
        instr_out <= Instruction;end
endmodule


module instruction_memory (
    input  wire [7:0] PC_Address,   // Comes from Member 1's PC_out
    output wire [7:0] Instruction   // Goes into Member 1's instr_in
);

    // -------------------------------------------------------------------------
    // The ROM Array
    // 256 memory slots, each holding an 8-bit instruction.
    // -------------------------------------------------------------------------
    reg [7:0] rom [0:255];

    // Asynchronous Read
    // The moment the PC changes, the new instruction instantly flows out.
    // -------------------------------------------------------------------------
    assign Instruction = rom[PC_Address];

endmodule


module top_processor(
    input  wire clk,
    input  wire reset,
    input  wire [7:0] instr_in,
    output wire [7:0] PC_out,
    output wire [7:0] instr_out
);

    wire [7:0] Instruction;
    wire [7:0] ir_instr_out;

    fetch_stage u_fetch (
        .clk    (clk),
        .reset  (reset),
        .PC_out (PC_out)
    );

    instruction_memory u_imem (
        .PC_Address  (PC_out),
        .Instruction (Instruction)
    );

    instruction_register u_ir (
        .clk         (clk),
        .reset       (reset),
        .Instruction (Instruction),
        .instr_out   (ir_instr_out)
    );

    pipeline_register u_pipeline (
        .clk       (clk),
        .reset     (reset),
        .instr_in  (ir_instr_out),
        .instr_out (instr_out)
    );

endmodule

