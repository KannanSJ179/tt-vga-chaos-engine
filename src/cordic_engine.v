`timescale 1ns / 1ps

module cordic_engine (
    input  wire       clk,
    input  wire       rst_n,      // Active-low synchronous reset
    input  wire       start,      // Pulse to begin computation
    input  wire [7:0] theta_in,   // 8-bit angle input (MSB first, then LSB)
    
    output reg  [7:0] sin_out,    // 8-bit Sine output (Q1.7)
    output reg  [7:0] cos_out,    // 8-bit Cosine output (Q1.7)
    output reg        valid       // High when results are ready
);

    reg  signed [15:0] x_reg, y_reg, z_reg;
    wire signed [15:0] x_next, y_next, z_next;
    
    wire [3:0]  iter;
    wire        fsm_en;
    wire        fsm_done;
    wire [15:0] lut_val;

    // --- Input Loading State Machine ---
    reg load_state;
    reg [7:0] theta_msb;
    wire cordic_start = (load_state == 1'b1);

    always @(posedge clk) begin
        if (!rst_n) begin
            load_state <= 1'b0;
            theta_msb  <= 8'd0;
        end else begin
            if (start && load_state == 1'b0) begin
                theta_msb  <= theta_in; 
                load_state <= 1'b1;
            end else if (load_state == 1'b1) begin
                load_state <= 1'b0;     
            end
        end
    end

    // --- Datapath Registers ---
    always @(posedge clk) begin
        if (!rst_n) begin
            x_reg <= 16'd0;
            y_reg <= 16'd0;
            z_reg <= 16'd0;
            valid <= 1'b0;
        end else if (cordic_start) begin
            x_reg <= 16'h4DBA;                     // Pre-scaled X initial value (K=0.60725)
            y_reg <= 16'd0;                        
            z_reg <= {theta_msb, theta_in};        
            valid <= 1'b0;
        end else if (fsm_en) begin
            x_reg <= x_next;
            y_reg <= y_next;
            z_reg <= z_next;
        end else if (fsm_done) begin
            cos_out <= x_reg[15:8];
            sin_out <= y_reg[15:8];
            valid   <= 1'b1;
        end
    end

    // --- Sub-Module Instantiations ---
    cordic_fsm u_fsm (
        .clk    (clk),
        .rst_n  (rst_n),
        .start  (cordic_start),
        .iter   (iter),
        .en     (fsm_en),
        .done   (fsm_done)
    );

    cordic_core_stage u_core (
        .x_in   (x_reg),
        .y_in   (y_reg),
        .z_in   (z_reg),
        .iter   (iter),
        .lut_val(lut_val),
        .x_next (x_next),
        .y_next (y_next),
        .z_next (z_next)
    );

    // --- Arctangent ROM (LUT) ---
    assign lut_val = (iter == 4'd0)  ? 16'h6487 :
                     (iter == 4'd1)  ? 16'h3B24 :
                     (iter == 4'd2)  ? 16'h1F5B :
                     (iter == 4'd3)  ? 16'h0FEA :
                     (iter == 4'd4)  ? 16'h07FD :
                     (iter == 4'd5)  ? 16'h03FF :
                     (iter == 4'd6)  ? 16'h01FF :
                     (iter == 4'd7)  ? 16'h00FF :
                     (iter == 4'd8)  ? 16'h007F :
                     (iter == 4'd9)  ? 16'h003F :
                     (iter == 4'd10) ? 16'h001F :
                     (iter == 4'd11) ? 16'h000F :
                     (iter == 4'd12) ? 16'h0007 :
                     (iter == 4'd13) ? 16'h0003 :
                     (iter == 4'd14) ? 16'h0001 : 16'h0000;

endmodule
