/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none
module ACC(
    input clk,
    input reset,
    input load,
    input [7:0] data_in,
    output reg [7:0] data_out
);

always @(posedge clk) begin
    if (reset)
        data_out <= 8'b00000000;
    else if (load)
        data_out <= data_in;
    else
        data_out <= data_out;
end

endmodule
