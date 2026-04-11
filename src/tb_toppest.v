module tb_Processor_Top();

    // 1. Testbench Signals
    reg clk;
    reg reset;
    wire [7:0] acc_monitor;
    wire [7:0] instr_monitor;  // NEW: Wire to catch the fetched instruction

    // 2. Instantiate the Grand Top-Level Module
    Processor_Top uut (
        .clk(clk),
        .reset(reset),
        .final_acc_value(acc_monitor),
        .fetched_instruction(instr_monitor) // NEW: Connect the port
    );

    // 3. Generate a 10ns Clock (100 MHz)
    always #5 clk = ~clk;

    // 4. Simulation and Memory Initialization
    integer i;

    initial begin
        // Initialize clock and reset
        clk = 0;
        reset = 1;

        // ---------------------------------------------------------------------
        // DATA MEMORY INITIALIZATION
        // ---------------------------------------------------------------------
        // Reach into Member 3's RAM and clear it to all zeros
        for(i = 0; i < 32; i = i + 1) begin
            uut.Stage2_Execute.mem.ram[i] = 8'd0;
        end
        // Pre-load Address 5 with the number 15 (0x0F) for testing
        uut.Stage2_Execute.mem.ram[5] = 8'd15;

        // ---------------------------------------------------------------------
        // INSTRUCTION MEMORY INITIALIZATION (The Test Program)
        // ---------------------------------------------------------------------
        // Reach into Member 1's ROM and load the instructions
        
        // Instr 0: LOAD from Mem[5] (Opcode 110, Operand 00101)
        uut.Stage1_Fetch.u_imem.rom[0] = 8'b110_00101;
        uut.Stage1_Fetch.u_imem.rom[1] = 8'b000_00100; 
        uut.Stage1_Fetch.u_imem.rom[2] = 8'b001_00010; 
        uut.Stage1_Fetch.u_imem.rom[3] = 8'b011_00111;
        uut.Stage1_Fetch.u_imem.rom[4] = 8'b100_11100;
        uut.Stage1_Fetch.u_imem.rom[5] = 8'b101_01111; 
        uut.Stage1_Fetch.u_imem.rom[6] = 8'b100_11100;  
        uut.Stage1_Fetch.u_imem.rom[7] = 8'b111_01010; 
        // Fill the rest with NOPs (using ADD 0 as a NOP)
        for(i = 8; i < 256; i = i + 1) begin
            uut.Stage1_Fetch.u_imem.rom[i] = 8'b000_00000;
        end

        // ---------------------------------------------------------------------
        // RUN THE PROCESSOR
        // ---------------------------------------------------------------------
        // Wait 20ns, then drop the reset to start the processor
        #20;
        reset = 0;

        // Wait enough clock cycles for the pipeline to fetch, decode, and execute
        #100; 
        
        // End simulation 
        $finish;
    end

endmodule
