`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 29.03.2026 10:43:54
// Design Name: 
// Module Name: data_memory
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


module data_memory(
    input         clk,
    input         Write_en,
    input   [7:0] Addr,      // SHRINK: Changed from [7:0] to [4:0] (5 bits)
    input   [7:0] Data_in,   // Data is still 8 bits wide!
    output [7:0] Data_out
);

    // -------------------------------------------------------------------------
    // OPTIMIZED RAM ARRAY
    // Exactly 32 mailboxes (0 to 31), each holding an 8-bit number.
    // -------------------------------------------------------------------------
    reg [7:0] ram [0:31]; 

    always @(posedge clk) begin
        if (Write_en) begin
            ram[Addr] <= Data_in;
        end
    end

    assign Data_out = ram[Addr];

endmodule

