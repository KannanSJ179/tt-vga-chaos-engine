module level_banner (
    input  wire       rst_n,
    input  wire       clk,
    input  wire       frames_clk,
    input  wire       lines_clk,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] pos_x,
    input  wire [9:0] pos_y,
    input  wire [5:0] RGB_Color,
    input  wire [3:0] level,        // 0..9 fits in 4 bits
    input  wire       paint_banner,
    output reg        active,
    output reg [1:0]  R,
    output reg [1:0]  G,
    output reg [1:0]  B
);

  localparam [9:0] SPRITE_WIDTH  = 10'd64;
  localparam [9:0] SPRITE_HEIGHT = 10'd16;

  localparam [3:0] PIXEL_WIDTH   = 4'd2;
  localparam [3:0] PIXEL_HEIGHT  = 4'd2;

  reg [9:0] left_x;
  reg [9:0] top_y;
  reg [9:0] rel_x;
  reg [9:0] rel_y;
  reg [6:0] bmp_col;
  reg [4:0] bmp_row;

  always @(posedge clk) begin
    if (!rst_n) begin
      active <= 1'b0;
      R      <= 2'b00;
      G      <= 2'b00;
      B      <= 2'b00;
    end else begin
      active <= 1'b0;
      R      <= 2'b00;
      G      <= 2'b00;
      B      <= 2'b00;

      left_x = pos_x - ((SPRITE_WIDTH  * PIXEL_WIDTH)  >> 1);
      top_y  = pos_y - ((SPRITE_HEIGHT * PIXEL_HEIGHT) >> 1);

      if ((x >= left_x) && (x < left_x + SPRITE_WIDTH * PIXEL_WIDTH) &&
          (y >= top_y)  && (y < top_y  + SPRITE_HEIGHT * PIXEL_HEIGHT) &&
          paint_banner) begin

        rel_x = x - left_x;
        rel_y = y - top_y;

        bmp_col = rel_x / PIXEL_WIDTH;
        bmp_row = rel_y / PIXEL_HEIGHT;

        if (start_banner_pixel(bmp_row, bmp_col, level)) begin
          active <= 1'b1;
          R <= RGB_Color[5:4];
          G <= RGB_Color[3:2];
          B <= RGB_Color[1:0];
        end
      end
    end
  end

  function automatic start_banner_pixel;
    input [4:0] row;
    input [6:0] col;
    input [3:0] level;
    reg   [63:0] row_bitmap;
    reg   [6:0] bitmap_index;
    begin
      case (row)
        5'd0:  row_bitmap = 64'b1000_1110_1010_1110_1000_0001_1100_0100_1110_1110_1010_1110_1110_1110_1110_1110;
        5'd1:  row_bitmap = 64'b1000_1000_1010_1000_1000_0001_0100_1100_0010_0010_1010_1000_1000_0010_1010_1010;
        5'd2:  row_bitmap = 64'b1000_1000_1010_1000_1000_0001_0101_0100_0010_0010_1010_1000_1000_0010_1010_1010;
        5'd3:  row_bitmap = 64'b1000_1000_1010_1000_1000_0001_0100_0100_0010_0010_1010_1000_1000_0010_1010_1010;
        5'd4:  row_bitmap = 64'b1000_1100_1010_1100_1000_0001_0100_0100_1110_1110_1010_1110_1110_0010_1110_1110;
        5'd5:  row_bitmap = 64'b1000_1000_1010_1000_1000_0001_0100_0100_1000_0010_1110_0010_1010_0010_1010_0010;
        5'd6:  row_bitmap = 64'b1000_1000_1000_1000_1000_0001_0100_0100_1000_0010_0010_0010_1010_0010_1010_0010;
        5'd7:  row_bitmap = 64'b1000_1000_0100_1000_1000_0001_0100_0100_1000_0010_0010_0010_1010_0010_1010_0010;
        5'd8:  row_bitmap = 64'b1110_1110_0100_1110_1110_0001_1100_0100_1110_1110_0010_1110_1110_0010_1110_0010;
        5'd9:  row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd10: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd11: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd12: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd13: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd14: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd15: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        default: row_bitmap = 64'b0;
      endcase

      start_banner_pixel = 1'b0;

      // col is 0..63 from left to right in the sprite

      // Fixed "LEVEL" region:
      // sprite columns 0..22 map to bitmap bits 63..41
      if (col <= 7'd22) begin
        bitmap_index = 7'd63 - col;
        start_banner_pixel = row_bitmap[bitmap_index];
      end
      // Digit region:
      // sprite columns 23..26 map to one selected 4-bit digit slot
      else if ((col >= 7'd23) && (col <= 7'd26) && (level <= 4'd9)) begin
        // level 0 -> bits 40..37
        // level 1 -> bits 36..33
        // ...
        // level 9 -> bits 4..1
        bitmap_index = 7'd40 - ((level << 2) + (col - 7'd23));
        start_banner_pixel = row_bitmap[bitmap_index];
      end
      else begin
        start_banner_pixel = 1'b0;
      end
    end
  endfunction

endmodule
