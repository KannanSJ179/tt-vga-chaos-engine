module Processor_Top (
    input  wire clk,
    input  wire reset,
    output wire [7:0] final_acc_value,
    output wire [7:0] fetched_instruction  // NEW: Exposes the instruction to the simulator
);

    // Internal wires connecting Stage 1 to Stage 2
    wire [7:0] pipeline_instr_wire;
    wire [7:0] pc_monitor_wire;

    // -------------------------------------------------------------------------
    // WIRING INTERNAL SIGNALS TO OUTPUTS
    // -------------------------------------------------------------------------
    // This routes the instruction that is about to be executed out to your testbench
    assign fetched_instruction = pipeline_instr_wire;

    // -------------------------------------------------------------------------
    // STAGE 1: Fetch and Pipeline (Member 1's Wrapper)
    // -------------------------------------------------------------------------
    top_processor Stage1_Fetch (
        .clk(clk),
        .reset(reset),
        .instr_in(8'b00000000),         // Unused in current design, tied to 0
        .PC_out(pc_monitor_wire),
        .instr_out(pipeline_instr_wire) // The instruction passed across the pipeline
    );

    // -------------------------------------------------------------------------
    // STAGE 2: Execute and Memory (Member 2 & 3's Wrapper)
    // -------------------------------------------------------------------------
    WrapperEx Stage2_Execute (
        .clk(clk),
        .reset(reset),
        .instr(pipeline_instr_wire),    // Receives the instruction from Stage 1
        .acc_out_final(final_acc_value)
    );

endmodule
