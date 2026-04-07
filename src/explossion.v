
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

  localparam [7:0] SPRITE_WIDTH  = 24;
  localparam [7:0] SPRITE_HEIGHT = 24;

  localparam [3:0] SPRITES_COUNT = 4'd5;
  localparam [15:0] FRAMES_DELAY = 16'h0960;

  reg [9:0] my_x;
  reg [9:0] my_y;
  reg [3:0] counter;
  reg [15:0] frames_counter;
  reg [1:0] direction;
  reg explode;

  always @(posedge lines_clk) begin
    if (!rst_n) begin
      frames_counter <= 16'd0;
      counter <= 4'd0;
      direction <= 2'd0;
      explode <= 1'b0;
      exploding <= 1'b0;
      my_x <= 10'd0;
      my_y <= 10'd0;
    end else begin
      exploding <= explode;

      if (my_number[0] && !control[0]) begin
        if (fire && !explode) begin
          explode <= 1'b1;
          exploding <= 1'b1;
          my_x <= pos_x;
          my_y <= pos_y;
          counter <= 4'd0;
          direction <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (my_number[1] && control[0] && !control[1]) begin
        if (fire && !explode) begin
          explode <= 1'b1;
          exploding <= 1'b1;
          my_x <= pos_x;
          my_y <= pos_y;
          counter <= 4'd0;
          direction <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (my_number[2] && control[0] && control[1] && !control[2]) begin
        if (fire && !explode) begin
          explode <= 1'b1;
          exploding <= 1'b1;
          my_x <= pos_x;
          my_y <= pos_y;
          counter <= 4'd0;
          direction <= 2'd0;
          frames_counter <= 16'd0;
        end
      end

      if (my_number[3] && control[0] && control[1] && control[2] && !control[3]) begin
        if (fire && !explode) begin
          explode <= 1'b1;
          exploding <= 1'b1;
          my_x <= pos_x;
          my_y <= pos_y;
          counter <= 4'd0;
          direction <= 2'd0;
          frames_counter <= 16'd0;
        end
      end


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
              explode <= 1'b0;
              exploding <= 1'b0;
            end
            counter <= counter - 1'b1;
          end
          frames_counter <= 16'd0;
        end
      end

    end
  end

  always @(posedge clk) begin
    if (!rst_n) begin
      active <= 1'b0;
      R <= 2'b00;
      G <= 2'b00;
      B <= 2'b00;
    end else begin
      active <= 1'b0;
      R <= 2'b00;
      G <= 2'b00;
      B <= 2'b00;

      if (explode) begin
        // upper half
        if ((y > (my_y - SPRITE_HEIGHT)) && (y <= my_y)) begin
          if ((x > (my_x - SPRITE_WIDTH)) && (x <= my_x)) begin
            if (
              (counter == 4'd0 && sprite_0_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, my_x - x)) ||
              (counter == 4'd1 && sprite_1_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, my_x - x)) ||
              (counter == 4'd2 && sprite_2_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, my_x - x)) ||
              (counter == 4'd3 && sprite_3_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, my_x - x)) ||
              (counter == 4'd4 && sprite_4_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, my_x - x)) ||
              (counter == 4'd5 && sprite_5_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, my_x - x))
            ) begin
              active <= 1'b1;
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end
          end else if ((x > my_x) && (x <= my_x + SPRITE_WIDTH)) begin
            if (
              (counter == 4'd0 && sprite_0_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, x - my_x - 1'b1)) ||
              (counter == 4'd1 && sprite_1_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, x - my_x - 1'b1)) ||
              (counter == 4'd2 && sprite_2_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, x - my_x - 1'b1)) ||
              (counter == 4'd3 && sprite_3_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, x - my_x - 1'b1)) ||
              (counter == 4'd4 && sprite_4_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, x - my_x - 1'b1)) ||
              (counter == 4'd5 && sprite_5_pixel(y - my_y + SPRITE_HEIGHT - 1'b1, x - my_x - 1'b1))
            ) begin
              active <= 1'b1;
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end
          end
        end
        // lower half
        else if ((y > my_y) && (y <= my_y + SPRITE_HEIGHT)) begin
          if ((x > (my_x - SPRITE_WIDTH)) && (x <= my_x)) begin
            if (
              (counter == 4'd0 && sprite_0_pixel(my_y + SPRITE_HEIGHT - y, my_x - x)) ||
              (counter == 4'd1 && sprite_1_pixel(my_y + SPRITE_HEIGHT - y, my_x - x)) ||
              (counter == 4'd2 && sprite_2_pixel(my_y + SPRITE_HEIGHT - y, my_x - x)) ||
              (counter == 4'd3 && sprite_3_pixel(my_y + SPRITE_HEIGHT - y, my_x - x)) ||
              (counter == 4'd4 && sprite_4_pixel(my_y + SPRITE_HEIGHT - y, my_x - x)) ||
              (counter == 4'd5 && sprite_5_pixel(my_y + SPRITE_HEIGHT - y, my_x - x))
            ) begin
              active <= 1'b1;
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end
          end else if ((x > my_x) && (x <= my_x + SPRITE_WIDTH)) begin
            if (
              (counter == 4'd0 && sprite_0_pixel(my_y + SPRITE_HEIGHT - y, x - my_x - 1'b1)) ||
              (counter == 4'd1 && sprite_1_pixel(my_y + SPRITE_HEIGHT - y, x - my_x - 1'b1)) ||
              (counter == 4'd2 && sprite_2_pixel(my_y + SPRITE_HEIGHT - y, x - my_x - 1'b1)) ||
              (counter == 4'd3 && sprite_3_pixel(my_y + SPRITE_HEIGHT - y, x - my_x - 1'b1)) ||
              (counter == 4'd4 && sprite_4_pixel(my_y + SPRITE_HEIGHT - y, x - my_x - 1'b1)) ||
              (counter == 4'd5 && sprite_5_pixel(my_y + SPRITE_HEIGHT - y, x - my_x - 1'b1))
            ) begin
              active <= 1'b1;
              R <= RGB_color[5:4];
              G <= RGB_color[3:2];
              B <= RGB_color[1:0];
            end
          end
        end
      end
    end
  end

  function automatic sprite_0_pixel;
    input [4:0] row;
    input [4:0] col;
    reg[23:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd1:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd2:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd3:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd4:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd5:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd6:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd7:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd8:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd9:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd10: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd11: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd12: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd13: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd14: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd15: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd16: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd17: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd18: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd19: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd20: row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        5'd21: row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        5'd22: row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        5'd23: row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        default: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
      endcase

      sprite_0_pixel = row_bitmap[col];
    end
  endfunction

  function automatic sprite_1_pixel;
    input [4:0] row;
    input [4:0] col;
    reg[23:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd1:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd2:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd3:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd4:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd5:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd6:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd7:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd8:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd9:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd10: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd11: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd12: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd13: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd14: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd15: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd16: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd17: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd18: row_bitmap = 24'b0000_0000_0000_0000_0000_0110;
        5'd19: row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        5'd20: row_bitmap = 24'b0000_0000_0000_0000_0011_1111;
        5'd21: row_bitmap = 24'b0000_0000_0000_0000_0111_1111;
        5'd22: row_bitmap = 24'b0000_0000_0000_0000_0111_1111;
        5'd23: row_bitmap = 24'b0000_0000_0000_0000_0011_1111;
        default: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
      endcase

      sprite_1_pixel = row_bitmap[col];
    end
  endfunction

  function automatic sprite_2_pixel;
    input [4:0] row;
    input [4:0] col;
    reg[23:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd1:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd2:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd3:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd4:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd5:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd6:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd7:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd8:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd9:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd10: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd11: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd12: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd13: row_bitmap = 24'b0000_0000_0000_0000_0000_0100;
        5'd14: row_bitmap = 24'b0000_0000_0000_0000_0001_1111;
        5'd15: row_bitmap = 24'b0000_0000_0000_0000_0001_1111;
        5'd16: row_bitmap = 24'b0000_0000_0000_0000_0001_1111;
        5'd17: row_bitmap = 24'b0000_0000_0000_0000_0001_1111;
        5'd18: row_bitmap = 24'b0000_0000_0000_0000_0001_1111;
        5'd19: row_bitmap = 24'b0000_0000_0000_0000_0001_1111;
        5'd20: row_bitmap = 24'b0000_0000_0000_0001_1111_1111;
        5'd21: row_bitmap = 24'b0000_0000_0000_0011_1111_1111;
        5'd22: row_bitmap = 24'b0000_0000_0000_0011_1111_1111;
        5'd23: row_bitmap = 24'b0000_0000_0000_0001_1111_1111;
        default: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
      endcase

      sprite_2_pixel = row_bitmap[col];
    end
  endfunction

  function automatic sprite_3_pixel;
    input [4:0] row;
    input [4:0] col;
    reg[23:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd1:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd2:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd3:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd4:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd5:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd6:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd7:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd8:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd9:  row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        5'd10: row_bitmap = 24'b0000_0000_0000_0000_0011_1111;
        5'd11: row_bitmap = 24'b0000_0000_0000_0000_1111_1111;
        5'd12: row_bitmap = 24'b0000_0000_0000_0011_1111_1111;
        5'd13: row_bitmap = 24'b0000_0000_0000_0111_1111_1111;
        5'd14: row_bitmap = 24'b0000_0000_0000_0111_1111_1111;
        5'd15: row_bitmap = 24'b0000_0000_0000_1111_1111_1111;
        5'd16: row_bitmap = 24'b0000_0000_0001_1111_1111_1111;
        5'd17: row_bitmap = 24'b0000_0000_0001_1111_1111_1111;
        5'd18: row_bitmap = 24'b0000_0000_0011_1111_1111_1111;
        5'd19: row_bitmap = 24'b0000_0000_0011_1111_1111_1111;
        5'd20: row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        5'd21: row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        5'd22: row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        5'd23: row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        default: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
      endcase

      sprite_3_pixel = row_bitmap[col];
    end
  endfunction

  function automatic sprite_4_pixel;
    input [4:0] row;
    input [4:0] col;
    reg[23:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd1:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd2:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd3:  row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
        5'd4:  row_bitmap = 24'b0000_0000_0000_0000_0011_1111;
        5'd5:  row_bitmap = 24'b0000_0000_0000_0000_1111_1111;
        5'd6:  row_bitmap = 24'b0000_0000_0000_0011_1111_1111;
        5'd7:  row_bitmap = 24'b0000_0000_0000_1111_1111_1111;
        5'd8:  row_bitmap = 24'b0000_0000_0001_1111_1111_1111;
        5'd9:  row_bitmap = 24'b0000_0000_0011_1111_1111_1111;
        5'd10: row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        5'd11: row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        5'd12: row_bitmap = 24'b0000_0000_1111_1111_1111_1111;
        5'd13: row_bitmap = 24'b0000_0001_1111_1111_1111_1111;
        5'd14: row_bitmap = 24'b0000_0011_1111_1111_1111_1111;
        5'd15: row_bitmap = 24'b0000_0011_1111_1111_1111_1111;
        5'd16: row_bitmap = 24'b0000_0011_1111_1111_1111_1111;
        5'd17: row_bitmap = 24'b0000_0111_1111_1111_1111_1111;
        5'd18: row_bitmap = 24'b0000_0111_1111_1111_1111_1111;
        5'd19: row_bitmap = 24'b0000_0111_1111_1111_1111_1111;
        5'd20: row_bitmap = 24'b0000_1111_1111_1111_1111_1111;
        5'd21: row_bitmap = 24'b0000_1111_1111_1111_1111_1111;
        5'd22: row_bitmap = 24'b0000_1111_1111_1111_1111_1111;
        5'd23: row_bitmap = 24'b0000_1111_1111_1111_1111_1111;
        default: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
      endcase

      sprite_4_pixel = row_bitmap[col];
    end
  endfunction

  function automatic sprite_5_pixel;
    input [4:0] row;
    input [4:0] col;
    reg[23:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 24'b0000_0000_0000_0000_0000_1111;
        5'd1:  row_bitmap = 24'b0000_0000_0000_0000_1111_1111;
        5'd2:  row_bitmap = 24'b0000_0000_0000_0011_1111_1111;
        5'd3:  row_bitmap = 24'b0000_0000_0000_1111_1111_1111;
        5'd4:  row_bitmap = 24'b0000_0000_0001_1111_1111_1111;
        5'd5:  row_bitmap = 24'b0000_0000_0111_1111_1111_1111;
        5'd6:  row_bitmap = 24'b0000_0000_1111_1111_1111_1111;
        5'd7:  row_bitmap = 24'b0000_0001_1111_1111_1111_1111;
        5'd8:  row_bitmap = 24'b0000_0011_1111_1111_1111_1111;
        5'd9:  row_bitmap = 24'b0000_0011_1111_1111_1111_1111;
        5'd10: row_bitmap = 24'b0000_0111_1111_1111_1111_1111;
        5'd11: row_bitmap = 24'b0000_1111_1111_1111_1111_1111;
        5'd12: row_bitmap = 24'b0001_1111_1111_1111_1111_1111;
        5'd13: row_bitmap = 24'b0001_1111_1111_1111_1111_1111;
        5'd14: row_bitmap = 24'b0011_1111_1111_1111_1111_1111;
        5'd15: row_bitmap = 24'b0011_1111_1111_1111_1111_1111;
        5'd16: row_bitmap = 24'b0011_1111_1111_1111_1111_1111;
        5'd17: row_bitmap = 24'b0111_1111_1111_1111_1111_1111;
        5'd18: row_bitmap = 24'b0111_1111_1111_1111_1111_1111;
        5'd19: row_bitmap = 24'b1111_1111_1111_1111_1111_1111;
        5'd20: row_bitmap = 24'b1111_1111_1111_1111_1111_1111;
        5'd21: row_bitmap = 24'b1111_1111_1111_1111_1111_1111;
        5'd22: row_bitmap = 24'b1111_1111_1111_1111_1111_1111;
        5'd23: row_bitmap = 24'b1111_1111_1111_1111_1111_1111;
        default: row_bitmap = 24'b0000_0000_0000_0000_0000_0000;
      endcase

      sprite_5_pixel = row_bitmap[col];
    end
  endfunction

endmodule
