module missile (
    input  wire       rst_n,
    input  wire       clk,
    input  wire       frames_clk,
    input  wire       lines_clk,
    input  wire [9:0] initial_x,
    input  wire [3:0] coefficient_x,
    input  wire [3:0] coefficient_y,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire       fire,
    input  wire [1:0] R_next,
    input  wire [1:0] G_next,
    input  wire [1:0] B_next,
    input  wire [5:0] RGBColor,
    input  wire [5:0] Explosion_RGBColor,
    input  wire [5:0] Fortress_RGBColor,
    input  wire [15:0] Lines_Delay,
    output reg        active,
    output wire       in_flight,
    output reg        impact,
    output reg [1:0]  R,
    output reg [1:0]  G,
    output reg [1:0]  B
);

  localparam [15:0] LINE_THICKNESS  = 16'd2;

  reg [9:0] init_x;
  reg [9:0] current_x;
  reg [9:0] current_y;
  reg [3:0] coeff_x;
  reg [3:0] coeff_y;
  reg [15:0] frames_counter;
  reg flying;
  reg reverse_x;

  assign in_flight = flying;

  reg        x_in_range;
  reg        y_in_range;
  reg [9:0]  dx;
  reg [15:0] lhs;
  reg [15:0] rhs;
  reg [15:0] diff;
  reg        line_hit;
  reg        collision_hit;

  // Registered request from pixel/render domain to motion domain
  reg        stop_request_r;
  reg        impact_request_r;

  always @(posedge lines_clk or negedge rst_n) begin
    if (!rst_n) begin
      init_x            <= 10'd0;
      current_x         <= 10'd0;
      current_y         <= 10'd0;
      coeff_x           <= 4'd0;
      coeff_y           <= 4'd0;
      frames_counter    <= 16'd0;
      flying            <= 1'b0;
      reverse_x         <= 1'b0;
      impact            <= 1'b0;
    end else begin
      if (fire && !flying) begin
        init_x            <= initial_x;
        current_x         <= initial_x;
        current_y         <= 10'd0;
        coeff_x           <= coefficient_x;
        coeff_y           <= coefficient_y;
        frames_counter    <= 16'd0;
        flying            <= 1'b1;
        impact            <= 1'b0;
        reverse_x         <= initial_x > 320 ? 1'b1 : 1'b0;
      end else if (flying) begin
        if (frames_counter + 1'b1 < Lines_Delay) begin
          frames_counter <= frames_counter + 1'b1;
        end else begin
          frames_counter <= 16'd0;

          if (current_y + coeff_y < 10'd480) begin
            current_y <= current_y + coeff_y;
          end else begin
            current_y <= 10'd479;
            flying    <= 1'b0;
          end

          if (reverse_x) begin
            if (current_x > coeff_x) begin
              current_x <= current_x - coeff_x;
            end else begin
              current_x <= 10'd0;
              flying    <= 1'b0;
            end
          end else begin
            if (current_x + coeff_x < 10'd640) begin
              current_x <= current_x + coeff_x;
            end else begin
              current_x <= 10'd639;
              flying    <= 1'b0;
            end
          end

          if (stop_request_r) begin
            flying <= 1'b0;
            if (impact_request_r)
              impact <= 1'b1;
          end
        end
      end
    end
  end

  always @(*) begin
    x_in_range    = 1'b0;
    y_in_range    = 1'b0;
    dx            = 10'd0;
    lhs           = 16'd0;
    rhs           = 16'd0;
    diff          = 16'd0;
    line_hit      = 1'b0;
    collision_hit = 1'b0;

    if (flying) begin
      if (!reverse_x)
        x_in_range = (x >= init_x) && (x <= current_x);
      else
        x_in_range = (x <= init_x) && (x >= current_x);

      y_in_range = (y <= current_y);

      if (x_in_range && y_in_range) begin
        if (!reverse_x)
          dx = x - init_x;
        else
          dx = init_x - x;

        lhs = dx * coeff_y;
        rhs = y  * coeff_x;

        if (lhs >= rhs)
          diff = lhs - rhs;
        else
          diff = rhs - lhs;

        if (diff <= LINE_THICKNESS)
          line_hit = 1'b1;
      end

      // Disabled for now to keep motion stable.
      collision_hit = 1'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      active <= 1'b0;
      R      <= 2'b00;
      G      <= 2'b00;
      B      <= 2'b00;
      stop_request_r   <= 1'b0;
      impact_request_r <= 1'b0;
    end else begin
      active <= 1'b0;
      R      <= 2'b00;
      G      <= 2'b00;
      B      <= 2'b00;

      if (fire && !flying) begin
        stop_request_r   <= 1'b0;
        impact_request_r <= 1'b0;
      end

      if (flying && line_hit && !collision_hit) begin
        if ((R_next == Explosion_RGBColor[5:4]) &&
            (G_next == Explosion_RGBColor[3:2]) &&
            (B_next == Explosion_RGBColor[1:0]) && (y >= current_y - coeff_y)) begin
          stop_request_r <= 1'b1;
        end
        if ((R_next == Fortress_RGBColor[5:4]) &&
            (G_next == Fortress_RGBColor[3:2]) &&
            (B_next == Fortress_RGBColor[1:0]) && (y >= current_y - coeff_y)) begin
          stop_request_r   <= 1'b1;
          impact_request_r <= 1'b1;
        end
        active <= 1'b1;
        R      <= RGBColor[5:4];
        G      <= RGBColor[3:2];
        B      <= RGBColor[1:0];
      end
    end
  end

endmodule
