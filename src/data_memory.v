/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module data_memory(
    input         clk,
    input         Write_en,
    input   [2:0] Addr,
    input   [7:0] Data_in,
    output  [7:0] Data_out
);

    // -------------------------------------------------------------------------
    // SHRINK RAM TO FIT IN SILICON
    // 8 mailboxes (0 to 7), each holding an 8-bit number.
    // -------------------------------------------------------------------------
    reg [7:0] ram [0:7]; 

    always @(posedge clk) begin
        if (Write_en) begin
            ram[Addr] <= Data_in; // Sliced to 3 bits
        end
    end

    assign Data_out = ram[Addr];  // Sliced to 3 bits

endmodule
