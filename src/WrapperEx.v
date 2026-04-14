/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module WrapperEx (
    input clk,
    input reset,
    input [7:0] instr,   // from pipeline register

    output [7:0] acc_out_final
);

//  Internal wires
wire [2:0] alu_op;
wire acc_load;
wire mem_write;

wire [7:0] operand_out;
wire [7:0] alu_result;
wire [7:0] acc_out;
wire [7:0] mem_data_out;

// DECODER
Decoder dec (
    .instr(instr),
    .alu_op(alu_op),
    .acc_load(acc_load),
    .mem_write(mem_write),
    .operand_out(operand_out)
);

// ALU
ALU_8 alu (
    .A(acc_out),
    .B(operand_out),
    .alu_op(alu_op),
    .result(alu_result)
);

// ACCUMULATOR
ACC acc (
    .clk(clk),
    .reset(reset),
    .load(acc_load),
    .data_in(
        (alu_op == 3'b110) ? mem_data_out : alu_result
        // LOAD ? Memory ? ACC
        // Others ? ALU ? ACC
    ),
    .data_out(acc_out)
);

// DATA MEMORY
data_memory mem (
    .clk(clk),
    .Write_en(mem_write),
    .Addr(operand_out[2:0]),
    .Data_in(acc_out),
    .Data_out(mem_data_out)
);

// OUTPUT
assign acc_out_final = acc_out;

endmodule
