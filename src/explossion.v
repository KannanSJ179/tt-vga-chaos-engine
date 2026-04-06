module explosion (
    input wire rst_n,
    input wire clk,
    input wire frames_clk,
    input wire lines_clk,
    input wire [9:0] x,
    input wire [9:0] y,
    input wire [9:0] pos_x,
    input wire [9:0] pos_y,
    input wire fire,
    input wire [15:0] control,
    input wire [15:0] my_number,
    input wire [5:0] RGB_color,
    output reg active,
    output reg exploding,
    output reg [1:0] R,
    output reg [1:0] G,
    output reg [1:0] B
);
  localparam [7:0] SPRITE_WIDTH  = 24;
  localparam [7:0] SPRITE_HEIGHT = 24;

  localparam [23:0] SPRITE_5 [23:0] = {
    24'b0000_0000_0000_0000_0000_1111,
    24'b0000_0000_0000_0000_1111_1111,
    24'b0000_0000_0000_0011_1111_1111,
    24'b0000_0000_0000_1111_1111_1111,
    24'b0000_0000_0001_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111,
    24'b0000_0000_1111_1111_1111_1111,
    24'b0000_0001_1111_1111_1111_1111,
    24'b0000_0011_1111_1111_1111_1111,
    24'b0000_0011_1111_1111_1111_1111,
    24'b0000_0111_1111_1111_1111_1111,
    24'b0000_1111_1111_1111_1111_1111,
    24'b0001_1111_1111_1111_1111_1111,
    24'b0001_1111_1111_1111_1111_1111,
    24'b0011_1111_1111_1111_1111_1111,
    24'b0011_1111_1111_1111_1111_1111,
    24'b0011_1111_1111_1111_1111_1111,
    24'b0111_1111_1111_1111_1111_1111,
    24'b0111_1111_1111_1111_1111_1111,
    24'b1111_1111_1111_1111_1111_1111,
    24'b1111_1111_1111_1111_1111_1111,
    24'b1111_1111_1111_1111_1111_1111,
    24'b1111_1111_1111_1111_1111_1111,
    24'b1111_1111_1111_1111_1111_1111
  };

  localparam [23:0] SPRITE_4 [23:0] = {
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0011_1111,
    24'b0000_0000_0000_0000_1111_1111,
    24'b0000_0000_0000_0011_1111_1111,
    24'b0000_0000_0000_1111_1111_1111,
    24'b0000_0000_0001_1111_1111_1111,
    24'b0000_0000_0011_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111,
    24'b0000_0000_1111_1111_1111_1111,
    24'b0000_0001_1111_1111_1111_1111,
    24'b0000_0011_1111_1111_1111_1111,
    24'b0000_0011_1111_1111_1111_1111,
    24'b0000_0011_1111_1111_1111_1111,
    24'b0000_0111_1111_1111_1111_1111,
    24'b0000_0111_1111_1111_1111_1111,
    24'b0000_0111_1111_1111_1111_1111,
    24'b0000_1111_1111_1111_1111_1111,
    24'b0000_1111_1111_1111_1111_1111,
    24'b0000_1111_1111_1111_1111_1111,
    24'b0000_1111_1111_1111_1111_1111
  };

  localparam [23:0] SPRITE_3 [23:0] = {
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_1111,
    24'b0000_0000_0000_0000_0011_1111,
    24'b0000_0000_0000_0000_1111_1111,
    24'b0000_0000_0000_0011_1111_1111,
    24'b0000_0000_0000_0111_1111_1111,
    24'b0000_0000_0000_0111_1111_1111,
    24'b0000_0000_0000_1111_1111_1111,
    24'b0000_0000_0001_1111_1111_1111,
    24'b0000_0000_0001_1111_1111_1111,
    24'b0000_0000_0011_1111_1111_1111,
    24'b0000_0000_0011_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111,
    24'b0000_0000_0111_1111_1111_1111
  };

  localparam [23:0] SPRITE_2 [23:0] = {
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0100,
    24'b0000_0000_0000_0000_0001_1111,
    24'b0000_0000_0000_0000_0001_1111,
    24'b0000_0000_0000_0000_0001_1111,
    24'b0000_0000_0000_0000_0001_1111,
    24'b0000_0000_0000_0000_0001_1111,
    24'b0000_0000_0000_0000_0001_1111,
    24'b0000_0000_0000_0001_1111_1111,
    24'b0000_0000_0000_0011_1111_1111,
    24'b0000_0000_0000_0011_1111_1111,
    24'b0000_0000_0000_0001_1111_1111
  };

  localparam [23:0] SPRITE_1 [23:0] = {
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0110,
    24'b0000_0000_0000_0000_0000_1111,
    24'b0000_0000_0000_0000_0011_1111,
    24'b0000_0000_0000_0000_0111_1111,
    24'b0000_0000_0000_0000_0111_1111,
    24'b0000_0000_0000_0000_0011_1111
  };

  localparam [23:0] SPRITE_0 [23:0] = {
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_0000,
    24'b0000_0000_0000_0000_0000_1111,
    24'b0000_0000_0000_0000_0000_1111,
    24'b0000_0000_0000_0000_0000_1111,
    24'b0000_0000_0000_0000_0000_1111
  };

  localparam SPRITES_COUNT = 4'b0101;
  localparam FRAMES_DELAY  = 16'h0960;

  reg [9:0] my_x;
  reg [9:0] my_y;
  reg [3:0] counter;
  reg [15:0] frames_counter;
  reg [1:0] direction;
  reg current_pixel;
  reg explode;

  assign exploding = explode;

  always @(posedge lines_clk) begin
    if (~rst_n) begin
      active <= 0;
      frames_counter <= 0;
      counter <= 0;
      direction <= 0;
      explode <= 0;
    end else begin
      if (my_number[0] && !control[0]) begin
        if (fire && !explode) begin
          explode <= 1;
          my_x <= pos_x;
          my_y <= pos_y;
        end
      end

      if (my_number[1] && control[0] && !control[1]) begin
        if (fire && !explode) begin
          explode <= 1;
          my_x <= pos_x;
          my_y <= pos_y;
        end
      end

      if (my_number[2] && control[0] && control[1] && !control[2]) begin
        if (fire && !explode) begin
          explode <= 1;
          my_x <= pos_x;
          my_y <= pos_y;
        end
      end

      if (my_number[3] && control[0] && control[1] && control[2] && !control[3]) begin
        if (fire && !explode) begin
          explode <= 1;
          my_x <= pos_x;
          my_y <= pos_y;
        end
      end
    end
  end

  always @(posedge lines_clk) begin
    if (explode) begin
      if (frames_counter + 1'b1 < FRAMES_DELAY) begin
        frames_counter <= frames_counter + 1'b1;
      end else begin
        if (direction[0] == 1'b0) begin
          if (counter + 1'b1 < SPRITES_COUNT)
            counter <= counter + 1'b1;
          else
            direction <= direction + 1'b1;
        end else begin
          if (counter - 1'b1 == 0) begin
            direction <= direction + 1'b1;
            explode <= 0;
          end
          counter <= counter - 1'b1;
        end
        frames_counter <= 0;
      end
    end
  end

  always @(posedge clk) begin
    if (~rst_n) begin
      active <= 0;
      my_x <= 0;
      my_y <= 0;
    end else begin
      if (explode) begin
        if ((y > (my_y - SPRITE_HEIGHT)) && (y <= my_y)) begin
          if ((x > (my_x - SPRITE_HEIGHT)) && (x <= my_x)) begin
            active <= 1;

            if (counter == 0)       current_pixel <= SPRITE_0[my_y - y][(my_x - x)];
            else if (counter == 1)  current_pixel <= SPRITE_1[my_y - y][(my_x - x)];
            else if (counter == 2)  current_pixel <= SPRITE_2[my_y - y][(my_x - x)];
            else if (counter == 3)  current_pixel <= SPRITE_3[my_y - y][(my_x - x)];
            else if (counter == 4)  current_pixel <= SPRITE_4[my_y - y][(my_x - x)];
            else if (counter == 5)  current_pixel <= SPRITE_5[my_y - y][(my_x - x)];
            else                    counter <= 0;

            if (current_pixel == 1'b1) begin
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end else begin
              active <= 0; R <= 2'b00; G <= 2'b00; B <= 2'b11;
            end

          end else if ((x > my_x) && (x <= my_x + SPRITE_WIDTH)) begin
            active <= 1;

            if (counter == 0)       current_pixel <= SPRITE_0[my_y - y][x - my_x - 1];
            else if (counter == 1)  current_pixel <= SPRITE_1[my_y - y][x - my_x - 1];
            else if (counter == 2)  current_pixel <= SPRITE_2[my_y - y][x - my_x - 1];
            else if (counter == 3)  current_pixel <= SPRITE_3[my_y - y][x - my_x - 1];
            else if (counter == 4)  current_pixel <= SPRITE_4[my_y - y][x - my_x - 1];
            else if (counter == 5)  current_pixel <= SPRITE_5[my_y - y][x - my_x - 1];
            else                    counter <= 0;

            if (current_pixel == 1'b1) begin
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end else begin
              active <= 0; R <= 2'b00; G <= 2'b00; B <= 2'b11;
            end

          end else begin
            active <= 0;
          end

        end else if ((y > my_y) && (y <= my_y + SPRITE_HEIGHT)) begin
          if ((x > (my_x - SPRITE_HEIGHT)) && (x <= my_x)) begin
            active <= 1;

            if (counter == 0)       current_pixel <= SPRITE_0[y - my_y - 1][(my_x - x)];
            else if (counter == 1)  current_pixel <= SPRITE_1[y - my_y - 1][(my_x - x)];
            else if (counter == 2)  current_pixel <= SPRITE_2[y - my_y - 1][(my_x - x)];
            else if (counter == 3)  current_pixel <= SPRITE_3[y - my_y - 1][(my_x - x)];
            else if (counter == 4)  current_pixel <= SPRITE_4[y - my_y - 1][(my_x - x)];
            else if (counter == 5)  current_pixel <= SPRITE_5[y - my_y - 1][(my_x - x)];
            else                    counter <= 0;

            if (current_pixel == 1'b1) begin
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end else begin
              active <= 0; R <= 2'b00; G <= 2'b00; B <= 2'b11;
            end

          end else if ((x > my_x) && (x <= my_x + SPRITE_WIDTH)) begin
            active <= 1;

            if (counter == 0)       current_pixel <= SPRITE_0[y - my_y - 1][x - my_x - 1];
            else if (counter == 1)  current_pixel <= SPRITE_1[y - my_y - 1][x - my_x - 1];
            else if (counter == 2)  current_pixel <= SPRITE_2[y - my_y - 1][x - my_x - 1];
            else if (counter == 3)  current_pixel <= SPRITE_3[y - my_y - 1][x - my_x - 1];
            else if (counter == 4)  current_pixel <= SPRITE_4[y - my_y - 1][x - my_x - 1];
            else if (counter == 5)  current_pixel <= SPRITE_5[y - my_y - 1][x - my_x - 1];
            else                    counter <= 0;

            if (current_pixel == 1'b1) begin
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end else begin
              active <= 0; R <= 2'b00; G <= 2'b00; B <= 2'b11;
            end

          end else begin
            active <= 0;
          end

        end else begin
          active <= 0;
        end
      end
    end
  end

endmodule
