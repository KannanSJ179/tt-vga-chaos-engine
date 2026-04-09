module explosion (
    input  wire       rst_n,
    input  wire       clk,
    input  wire       frames_clk,
    input  wire       lines_clk,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] pos_x,
    input  wire [9:0] pos_y,
    input  wire       fire,
    input  wire [15:0] control,
    input  wire [15:0] my_number,
    input  wire [5:0] RGB_color,
    output reg        active,
    output reg        exploding,
    output reg [1:0]  R,
    output reg [1:0]  G,
    output reg [1:0]  B
);

  localparam [3:0]  STEPS_COUNT = 4'd6;   // stages 0..5
  localparam [15:0] FRAMES_DELAY = 16'h0960;

  reg [9:0]  my_x;
  reg [9:0]  my_y;
  reg [3:0]  counter;
  reg [15:0] frames_counter;
  reg [1:0]  direction;
  reg        explode;

  reg [9:0] dx;
  reg [9:0] dy;
  reg [5:0] half_size;
  reg [5:0] cut_size;
  reg [5:0] row_limit;

  // --------------------------------------------------------------------------
  // Explosion state / animation timing
  // --------------------------------------------------------------------------
  always @(posedge lines_clk or negedge rst_n) begin
    if (!rst_n) begin
      frames_counter <= 16'd0;
      counter        <= 4'd0;
      direction      <= 2'd0;
      explode        <= 1'b0;
      exploding      <= 1'b0;
      my_x           <= 10'd0;
      my_y           <= 10'd0;
    end else begin
      exploding <= explode;

      if (my_number[0] && !control[0]) begin
        if (fire && !explode) begin
          explode        <= 1'b1;
          exploding      <= 1'b1;
          my_x           <= pos_x;
          my_y           <= pos_y;
          counter        <= 4'd0;
          direction      <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (my_number[1] && control[0] && !control[1]) begin
        if (fire && !explode) begin
          explode        <= 1'b1;
          exploding      <= 1'b1;
          my_x           <= pos_x;
          my_y           <= pos_y;
          counter        <= 4'd0;
          direction      <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (my_number[2] && control[0] && control[1] && !control[2]) begin
        if (fire && !explode) begin
          explode        <= 1'b1;
          exploding      <= 1'b1;
          my_x           <= pos_x;
          my_y           <= pos_y;
          counter        <= 4'd0;
          direction      <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (my_number[3] && control[0] && control[1] && control[2] && !control[3]) begin
        if (fire && !explode) begin
          explode        <= 1'b1;
          exploding      <= 1'b1;
          my_x           <= pos_x;
          my_y           <= pos_y;
          counter        <= 4'd0;
          direction      <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (explode) begin
        if (frames_counter + 1'b1 < FRAMES_DELAY) begin
          frames_counter <= frames_counter + 1'b1;
        end else begin
          if (direction[0] == 1'b0) begin
            if (counter + 1'b1 < STEPS_COUNT)
              counter <= counter + 1'b1;
            else
              direction <= direction + 1'b1;
          end else begin
            if (counter - 1'b1 == 0) begin
              direction <= direction + 1'b1;
              explode   <= 1'b0;
              exploding <= 1'b0;
            end
            counter <= counter - 1'b1;
          end
          frames_counter <= 16'd0;
        end
      end
    end
  end

  // --------------------------------------------------------------------------
  // Pixel painter
  // Procedural chamfered-square explosion:
  // - no sprites
  // - no multiplication/division
  // - only abs, compare, add/sub
  // --------------------------------------------------------------------------
  always @(posedge clk) begin
    if (!rst_n) begin
      active    <= 1'b0;
      R         <= 2'b00;
      G         <= 2'b00;
      B         <= 2'b00;
      dx        <= 10'd0;
      dy        <= 10'd0;
      half_size <= 6'd0;
      cut_size  <= 6'd0;
      row_limit <= 6'd0;
    end else begin
      active <= 1'b0;
      R      <= 2'b00;
      G      <= 2'b00;
      B      <= 2'b00;

      // absolute distances to explosion center
      if (x >= my_x)
        dx <= x - my_x;
      else
        dx <= my_x - x;

      if (y >= my_y)
        dy <= y - my_y;
      else
        dy <= my_y - y;

      // 6 fixed sizes:
      // total size = 4, 12, 20, 28, 36, 48
      // half size  = 2,  6, 10, 14, 18, 24
      case (counter)
        4'd0: half_size <= 6'd2;
        4'd1: half_size <= 6'd6;
        4'd2: half_size <= 6'd10;
        4'd3: half_size <= 6'd14;
        4'd4: half_size <= 6'd18;
        default: half_size <= 6'd24;
      endcase

      // chamfer amount:
      // trims the top/bottom rows so the explosion is less boxy
      // chosen as approx quarter of half-size, but via case to avoid division
      case (counter)
        4'd0: cut_size <= 6'd1;
        4'd1: cut_size <= 6'd2;
        4'd2: cut_size <= 6'd3;
        4'd3: cut_size <= 6'd4;
        4'd4: cut_size <= 6'd5;
        default: cut_size <= 6'd6;
      endcase

      // default full row width
      row_limit <= half_size;

      // reduce width on top/bottom edge bands
      // this creates the softened/chamfered corners
      if (dy >= (half_size - cut_size))
        row_limit <= half_size - cut_size;

      if (explode) begin
        if ((dx < half_size) && (dy < half_size) && (dx < row_limit)) begin
          active <= 1'b1;
          R      <= RGB_color[5:4];
          G      <= RGB_color[3:2];
          B      <= RGB_color[1:0];
        end
      end
    end
  end

endmodule
