module instruction_memory (
input wire [7:0] PC_Address,
output wire [7:0] Instruction
);
reg [7:0] rom [0:255];
assign Instruction = rom[PC_Address];
endmodule