module crosshair (
    input  wire       rst_n,
    input  wire       clk,
    input  wire       frames_clk,
    input  wire       lines_clk,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] pos_x,
    input  wire [9:0] pos_y,
    input  wire [5:0] RGB_Color,
    output reg        active,
    output reg [1:0]  R,
    output reg [1:0]  G,
    output reg [1:0]  B
);

  localparam [9:0] SPRITE_WIDTH  = 10;
  localparam [9:0] SPRITE_HEIGHT = 10;

  reg [3:0] row;
  reg [3:0] col;

  function automatic crosshair_pixel;
    input [3:0] r;
    input [3:0] c;
    begin
      case (r)
        4'd0: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd1: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd2: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd3: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd4: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd5: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd6: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd7: crosshair_pixel = (10'b00_0000_0011 >> c) & 1'b1;
        4'd8: crosshair_pixel = (10'b11_1111_1111 >> c) & 1'b1;
        4'd9: crosshair_pixel = (10'b11_1111_1111 >> c) & 1'b1;
        default: crosshair_pixel = 1'b0;
      endcase
    end
  endfunction

  always @(posedge clk) begin
    if (!rst_n) begin
      active <= 1'b0;
      R <= 2'b00;
      G <= 2'b00;
      B <= 2'b00;
      row <= 4'd0;
      col <= 4'd0;
    end else begin
      active <= 1'b0;
      R <= 2'b00;
      G <= 2'b00;
      B <= 2'b00;
      row <= 4'd0;
      col <= 4'd0;

      // Upper half
      if ((y > (pos_y - SPRITE_HEIGHT)) && (y <= pos_y)) begin
        if ((x > (pos_x - SPRITE_WIDTH)) && (x <= pos_x)) begin
          row <= pos_y - y;
          col <= pos_x - x;

          if (crosshair_pixel(pos_y - y, pos_x - x)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end else if ((x > pos_x) && (x <= pos_x + SPRITE_WIDTH)) begin
          row <= pos_y - y;
          col <= x - pos_x - 1'b1;

          if (crosshair_pixel(pos_y - y, x - pos_x - 1'b1)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end
      end
      // Lower half
      else if ((y > pos_y) && (y <= pos_y + SPRITE_HEIGHT)) begin
        if ((x > (pos_x - SPRITE_WIDTH)) && (x <= pos_x)) begin
          row <= y - pos_y - 1'b1;
          col <= pos_x - x;

          if (crosshair_pixel(y - pos_y - 1'b1, pos_x - x)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end else if ((x > pos_x) && (x <= pos_x + SPRITE_WIDTH)) begin
          row <= y - pos_y - 1'b1;
          col <= x - pos_x - 1'b1;

          if (crosshair_pixel(y - pos_y - 1'b1, x - pos_x - 1'b1)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end
      end
    end
  end

endmodule
