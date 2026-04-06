module crosshair (
    input wire rst_n,
    input wire clk,
    input wire frames_clk,
    input wire lines_clk,
    input wire [9:0] x,
    input wire [9:0] y,
    input wire [9:0] pos_x,
    input wire [9:0] pos_y,
    input wire [5:0] RGB_Color,
    output reg active,
    output reg [1:0] R,
    output reg [1:0] G,
    output reg [1:0] B
);
  localparam [7:0] SPRITE_WIDTH  = 10;
  localparam [7:0] SPRITE_HEIGHT = 10;

  localparam [9:0] CROSSHAIR [9:0] = {
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b00_0000_0011,
    10'b11_1111_1111,
    10'b11_1111_1111
  };

  always @(posedge frames_clk) begin
    if (~rst_n)
      active <= 0;
  end

  always @(posedge clk) begin
    if (~rst_n) begin
      active <= 0;
    end else begin
      if ((y > (pos_y - SPRITE_HEIGHT)) && (y <= pos_y)) begin
        if ((x > (pos_x - SPRITE_HEIGHT)) && (x <= pos_x)) begin
          active <= 1;

          if (CROSSHAIR[pos_y - y][(pos_x - x)] == 1'b1) begin
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end else begin
            R <= 2'b00; G <= 2'b00; B <= 2'b11; active <= 0;
          end

        end else if ((x > pos_x) && (x <= pos_x + SPRITE_WIDTH)) begin
          active <= 1;

          if (CROSSHAIR[pos_y - y][x - pos_x - 1] == 1'b1) begin
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end else begin
            R <= 2'b00; G <= 2'b00; B <= 2'b11; active <= 0;
          end

        end else begin
          active <= 0;
        end

      end else if ((y > pos_y) && (y <= pos_y + SPRITE_HEIGHT)) begin
        if ((x > (pos_x - SPRITE_HEIGHT)) && (x <= pos_x)) begin
          active <= 1;

          if (CROSSHAIR[y - pos_y - 1][(pos_x - x)] == 1'b1) begin
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end else begin
            R <= 2'b00; G <= 2'b00; B <= 2'b11; active <= 0;
          end

        end else if ((x > pos_x) && (x <= pos_x + SPRITE_WIDTH)) begin
          active <= 1;

          if (CROSSHAIR[y - pos_y - 1][x - pos_x - 1] == 1'b1) begin
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end else begin
            R <= 2'b00; G <= 2'b00; B <= 2'b11; active <= 0;
          end

        end else begin
          active <= 0;
        end

      end else begin
        active <= 0;
      end
    end
  end

endmodule
