/*
 * Copyright (c) 2026 Diego Satizabal
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_ds_missile_command(
  input  wire [7:0] ui_in,
  output wire [7:0] uo_out,
  input  wire [7:0] uio_in,
  output wire [7:0] uio_out,
  output wire [7:0] uio_oe,
  input  wire       ena,
  input  wire       clk,
  input  wire       rst_n
);

  // VGA signals
  wire hsync;
  wire vsync;
  wire [1:0] R;
  wire [1:0] G;
  wire [1:0] B;
  wire video_active;
  wire [9:0] pix_x;
  wire [9:0] pix_y;
  wire sound;

  assign uo_out = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};

  assign uio_out = 0;
  assign uio_oe  = 0;

  wire _unused_ok = &{ena, ui_in, uio_in};

  reg [1:0] impacts;

  reg [3:0] explosions;

  reg [15:0] counter;
  reg crosshair_active;
  reg [1:0] crosshair_R;
  reg [1:0] crosshair_G;
  reg [1:0] crosshair_B;
  reg [9:0] crosshair_x;
  reg [9:0] crosshair_y;

  localparam FRAMES_CROSSHAIR_DELAY = 16'h0100;
  localparam EXPLOSION_COUNT = 4;

  localparam CROSSHAIR_RGB_COLOR = 6'b00_1100;
  localparam FORTRESS_RGB_COLOR = 6'b01_0101;
  localparam EXPLOSSION_RGB_COLOR = 6'b11_1111;
  localparam MISSILE_RGB_COLOR = 6'b00_1100;

  wire [EXPLOSION_COUNT-1:0] explosion_active;
  wire [1:0] explosion_R [0:EXPLOSION_COUNT-1];
  wire [1:0] explosion_G [0:EXPLOSION_COUNT-1];
  wire [1:0] explosion_B [0:EXPLOSION_COUNT-1];

  reg inp_a_prev;
  reg fire_pulse;

  wire inp_b, inp_y, inp_select, inp_start, inp_up, inp_down, inp_left, inp_right, inp_a, inp_x, inp_l, inp_r;

  // ---------------- Missile system ----------------
  reg  [2:0] missile_fire;
  reg  [3:0] missile_fire_pulse;
  reg  [1:0] missiles_in_flight; // free-running pseudo-random source

  reg  [9:0] missile_start_x [0:2];
  reg  [3:0] missile_coeff_x [0:2];
  reg  [3:0] missile_coeff_y [0:2];

  wire [2:0] missile_active;
  wire [2:0] missile_flying;
  wire [1:0] missile_R [0:2];
  wire [1:0] missile_G [0:2];
  wire [1:0] missile_B [0:2];

  wire [9:0] starter_x;
  wire [3:0] starter_coeff_x;
  wire [3:0] starter_coeff_y;
  wire       starter_rev_x;

  reg missiles_gone_prev;
  wire missiles_gone;

  reg  [3:0] missile_impact;

  assign missiles_gone = (missile_flying == 3'b000);

  wire fortress_active;
  wire [1:0] fortress_R;
  wire [1:0] fortress_G;
  wire [1:0] fortress_B;

  integer i;
  reg [1:0] R_next;
  reg [1:0] G_next;
  reg [1:0] B_next;

  hvsync_generator hvsync_gen(
    .clk(clk),
    .reset(~rst_n),
    .hsync(hsync),
    .vsync(vsync),
    .display_on(video_active),
    .hpos(pix_x),
    .vpos(pix_y)
  );

  gamepad_pmod_single driver (
      .rst_n(rst_n),
      .clk(clk),
      .pmod_data(ui_in[6]),
      .pmod_clk(ui_in[5]),
      .pmod_latch(ui_in[4]),
      .b(inp_b),
      .y(inp_y),
      .select(inp_select),
      .start(inp_start),
      .up(inp_up),
      .down(inp_down),
      .left(inp_left),
      .right(inp_right),
      .a(inp_a),
      .x(inp_x),
      .l(inp_l),
      .r(inp_r),
      .is_present()
  );

  explosion exp_0 (
      .rst_n(rst_n),
      .clk(clk),
      .frames_clk(vsync),
      .lines_clk(hsync),
      .x(pix_x),
      .y(pix_y),
      .pos_x(crosshair_x),
      .pos_y(crosshair_y),
      .fire(fire_pulse),
      .control(explosions),
      .my_number(16'b0000_0000_0000_0001),
      .RGB_color(EXPLOSSION_RGB_COLOR),
      .active(explosion_active[0]),
      .exploding(explosions[0]),
      .R(explosion_R[0]),
      .G(explosion_G[0]),
      .B(explosion_B[0])
  );

  explosion exp_1 (
      .rst_n(rst_n),
      .clk(clk),
      .frames_clk(vsync),
      .lines_clk(hsync),
      .x(pix_x),
      .y(pix_y),
      .pos_x(crosshair_x),
      .pos_y(crosshair_y),
      .fire(fire_pulse),
      .control(explosions),
      .my_number(16'b0000_0000_0000_0010),
      .RGB_color(EXPLOSSION_RGB_COLOR),
      .active(explosion_active[1]),
      .exploding(explosions[1]),
      .R(explosion_R[1]),
      .G(explosion_G[1]),
      .B(explosion_B[1])
  );

  explosion exp_2 (
      .rst_n(rst_n),
      .clk(clk),
      .frames_clk(vsync),
      .lines_clk(hsync),
      .x(pix_x),
      .y(pix_y),
      .pos_x(crosshair_x),
      .pos_y(crosshair_y),
      .fire(fire_pulse),
      .control(explosions),
      .my_number(16'b0000_0000_0000_0100),
      .RGB_color(EXPLOSSION_RGB_COLOR),
      .active(explosion_active[2]),
      .exploding(explosions[2]),
      .R(explosion_R[2]),
      .G(explosion_G[2]),
      .B(explosion_B[2])
  );

  explosion exp_3 (
      .rst_n(rst_n),
      .clk(clk),
      .frames_clk(vsync),
      .lines_clk(hsync),
      .x(pix_x),
      .y(pix_y),
      .pos_x(crosshair_x),
      .pos_y(crosshair_y),
      .fire(fire_pulse),
      .control(explosions),
      .my_number(16'b0000_0000_0000_1000),
      .RGB_color(EXPLOSSION_RGB_COLOR),
      .active(explosion_active[3]),
      .exploding(explosions[3]),
      .R(explosion_R[3]),
      .G(explosion_G[3]),
      .B(explosion_B[3])
  );

  missile_starter ms(
    .rst_n(rst_n),
    .clk(clk),
    .start_x(starter_x),
    .coefficient_x(starter_coeff_x),
    .coefficient_y(starter_coeff_y)
  );

  missile m_0 (
    .rst_n(rst_n),
    .clk(clk),
    .frames_clk(vsync),
    .lines_clk(hsync),
    .initial_x(missile_start_x[0]),
    .coefficient_x(missile_coeff_x[0]),
    .coefficient_y(missile_coeff_y[0]),
    .x(pix_x),
    .y(pix_y),
    .fire(missile_fire[0]),
    .R_next(R_next),
    .G_next(G_next),
    .B_next(B_next),
    .active(missile_active[0]),
    .in_flight(missile_flying[0]),
    .impact(missile_impact[0]),
    .R(missile_R[0]),
    .G(missile_G[0]),
    .B(missile_B[0])
  );

  missile m_1 (
    .rst_n(rst_n),
    .clk(clk),
    .frames_clk(vsync),
    .lines_clk(hsync),
    .initial_x(missile_start_x[1]),
    .coefficient_x(missile_coeff_x[1]),
    .coefficient_y(missile_coeff_y[1]),
    .x(pix_x),
    .y(pix_y),
    .fire(missile_fire[1]),
    .R_next(R_next),
    .G_next(G_next),
    .B_next(B_next),
    .active(missile_active[1]),
    .in_flight(missile_flying[1]),
    .impact(missile_impact[1]),
    .R(missile_R[1]),
    .G(missile_G[1]),
    .B(missile_B[1])
  );

  missile m_2 (
    .rst_n(rst_n),
    .clk(clk),
    .frames_clk(vsync),
    .lines_clk(hsync),
    .initial_x(missile_start_x[2]),
    .coefficient_x(missile_coeff_x[2]),
    .coefficient_y(missile_coeff_y[2]),
    .x(pix_x),
    .y(pix_y),
    .fire(missile_fire[2]),
    .R_next(R_next),
    .G_next(G_next),
    .B_next(B_next),
    .active(missile_active[2]),
    .in_flight(missile_flying[2]),
    .impact(missile_impact[2]),
    .R(missile_R[2]),
    .G(missile_G[2]),
    .B(missile_B[2])
  );

  crosshair c (
      .rst_n(rst_n),
      .clk(clk),
      .frames_clk(vsync),
      .lines_clk(hsync),
      .x(pix_x),
      .y(pix_y),
      .pos_x(crosshair_x),
      .pos_y(crosshair_y),
      .RGB_Color(CROSSHAIR_RGB_COLOR),
      .active(crosshair_active),
      .R(crosshair_R),
      .G(crosshair_G),
      .B(crosshair_B)
  );

  fortress f(
      .rst_n(rst_n),
      .clk(clk),
      .frames_clk(vsync),
      .lines_clk(hsync),
      .x(pix_x),
      .y(pix_y),
      .remaining_hits(impacts),
      .RGB_Color(FORTRESS_RGB_COLOR),
      .active(fortress_active),
      .R(fortress_R),
      .G(fortress_G),
      .B(fortress_B)
  );

  // Sprites multiplexor
  always @(*) begin
    R_next = 2'b00;
    G_next = 2'b00;
    B_next = 2'b11;

    if (!video_active || impacts == 2'b00) begin
      R_next = 2'b00;
      G_next = 2'b00;
      B_next = 2'b00;
    end else begin
      // explosions
      for (i = 0; i < EXPLOSION_COUNT; i = i + 1) begin
        if (explosion_active[i]) begin
          R_next = explosion_R[i];
          G_next = explosion_G[i];
          B_next = explosion_B[i];
        end
      end

      // missiles
      for (i = 0; i < 3; i = i + 1) begin
        if (missile_active[i]) begin
          R_next = missile_R[i];
          G_next = missile_G[i];
          B_next = missile_B[i];
        end
      end

      // Fortress
      if (fortress_active) begin
        R_next = fortress_R;
        G_next = fortress_G;
        B_next = fortress_B;
      end

      // crosshair on top
      if (crosshair_active) begin
        R_next = crosshair_R;
        G_next = crosshair_G;
        B_next = crosshair_B;
      end
    end
  end

  assign R = R_next;
  assign G = G_next;
  assign B = B_next;

  // Fix separate edges
  always @(posedge missile_impact[0]) begin
    impacts <= impacts - 1'b1;
  end
  always @(posedge missile_impact[1]) begin
    impacts <= impacts - 1'b1;
  end
  always @(posedge missile_impact[2]) begin
    impacts <= impacts - 1'b1;
  end
  always @(posedge inp_select) begin
    if (impacts == 2'b00) begin
      impacts <= 2'b11;
    end
  end

  always @(posedge hsync) begin
    if (!rst_n) begin
      inp_a_prev         <= 1'b0;
      fire_pulse         <= 1'b0;

      missile_fire       <= 3'b000;
      missile_fire_pulse <= 4'd0;
      missiles_in_flight <= 2'd1;
      missiles_gone_prev <= 1'b0; // force first wave after reset

      counter <= 0;
      crosshair_x <= 320;
      crosshair_y <= 240;
      impacts <= 2'b11;
    end else begin
      // Bomb fire pulse
      fire_pulse <= inp_a & ~inp_a_prev;
      inp_a_prev <= inp_a;

      // Free-running pseudo-random source
      if (missiles_in_flight + 1'b1 == 2'b00) begin
        missiles_in_flight <= 2'b01;
      end else begin
        missiles_in_flight <= missiles_in_flight + 1'b1;
      end

      // Track previous all-gone state
      missiles_gone_prev <= missiles_gone;

      // Missile fire pulse countdown
      if (missile_fire_pulse > 0) begin
        missile_fire_pulse <= missile_fire_pulse - 1'b1;
        if (missile_fire_pulse == 4'd1)
          missile_fire <= 3'b000;
      end

      // Launch only on transition into "all missiles gone"
      if (missiles_gone && !missiles_gone_prev) begin
        missile_fire_pulse <= 4'b1111;
        missile_fire       <= 3'b000;

        // Always launch missile 0
        missile_fire[0]      <= 1'b1;
        missile_start_x[0]   <= starter_x;
        missile_coeff_x[0]   <= starter_coeff_x;
        missile_coeff_y[0]   <= starter_coeff_y;

        // Launch missile 1 for sampled values 2 or 3
        if (missiles_in_flight >= 2'd2) begin
          missile_fire[1]      <= 1'b1;
          missile_start_x[1]   <= starter_x + 120;
          missile_coeff_x[1]   <= starter_coeff_x;
          missile_coeff_y[1]   <= starter_coeff_y;
        end

        // Launch missile 2 only for sampled value 3
        if (missiles_in_flight == 2'd3) begin
          missile_fire[2]      <= 1'b1;
          missile_start_x[2]   <= starter_x + 10'd320;
          missile_coeff_x[2]   <= starter_coeff_x;
          missile_coeff_y[2]   <= starter_coeff_y;
        end
      end

      // Crosshair
      if (inp_up) begin
        if (counter + 1'b1 < FRAMES_CROSSHAIR_DELAY) begin
          counter <= counter + 1'b1;
        end else begin
          counter <= 0;
          if (crosshair_y - 1'b1 > 0)
            crosshair_y <= crosshair_y - 2'b11;
        end
      end

      if (inp_down) begin
        if (counter + 1'b1 < FRAMES_CROSSHAIR_DELAY) begin
          counter <= counter + 1'b1;
        end else begin
          counter <= 0;
          if (crosshair_y + 1'b1 <= 480)
            crosshair_y <= crosshair_y + 2'b11;
        end
      end

      if (inp_left) begin
        if (counter + 1'b1 < FRAMES_CROSSHAIR_DELAY) begin
          counter <= counter + 1'b1;
        end else begin
          counter <= 0;
          if (crosshair_x - 1'b1 > 0)
            crosshair_x <= crosshair_x - 2'b11;
        end
      end

      if (inp_right) begin
        if (counter + 1'b1 < FRAMES_CROSSHAIR_DELAY) begin
          counter <= counter + 1'b1;
        end else begin
          counter <= 0;
          if (crosshair_x + 1'b1 <= 640)
            crosshair_x <= crosshair_x + 2'b11;
        end
      end
    end
  end

endmodule
