module start_banner (
    input  wire       rst_n,
    input  wire       clk,
    input  wire       frames_clk,
    input  wire       lines_clk,
    input  wire [9:0] x,
    input  wire [9:0] y,
    input  wire [9:0] pos_x,
    input  wire [9:0] pos_y,
    input  wire [5:0] RGB_Color,
    input  wire       paint_banner,
    output reg        active,
    output reg [1:0]  R,
    output reg [1:0]  G,
    output reg [1:0]  B
);

  localparam [9:0] SPRITE_WIDTH  = 10'd64;
  localparam [9:0] SPRITE_HEIGHT = 10'd16;

  localparam [3:0] PIXEL_WIDTH_SHIFT  = 4'd2;
  localparam [3:0] PIXEL_HEIGHT_SHIFT = 4'd1;

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

      left_x = pos_x - ((SPRITE_WIDTH  << PIXEL_WIDTH_SHIFT)  >> 1);
      top_y  = pos_y - ((SPRITE_HEIGHT << PIXEL_HEIGHT_SHIFT) >> 1);

      if ((x >= left_x) && (x < (left_x + (SPRITE_WIDTH  << PIXEL_WIDTH_SHIFT))) &&
          (y >= top_y)  && (y < (top_y  + (SPRITE_HEIGHT << PIXEL_HEIGHT_SHIFT))) &&
          paint_banner) begin

        rel_x = x - left_x;
        rel_y = y - top_y;

        bmp_col = rel_x >> PIXEL_WIDTH_SHIFT;
        bmp_row = rel_y >> PIXEL_HEIGHT_SHIFT;

        if (start_banner_pixel(bmp_row, bmp_col)) begin
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
    reg   [63:0] row_bitmap;
    begin
      case (row)
        5'd0:  row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd1:  row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd2:  row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd3:  row_bitmap = 64'b0000_0000_0001_1001_1001_1101_1101_1100_0111_0111_0111_0110_0111_0000_0000_0000;
        5'd4:  row_bitmap = 64'b0000_0000_0001_0101_0101_0001_0001_0000_0100_0010_0101_0101_0010_0000_0000_0000;
        5'd5:  row_bitmap = 64'b0000_0000_0001_0101_0101_0001_0001_0000_0100_0010_0101_0101_0010_0000_0000_0000;
        5'd6:  row_bitmap = 64'b0000_0000_0001_0101_0101_0001_0001_0000_0100_0010_0101_0101_0010_0000_0000_0000;
        5'd7:  row_bitmap = 64'b0000_0000_0001_1001_1001_1001_1101_1100_0111_0010_0111_0110_0010_0000_0000_0000;
        5'd8:  row_bitmap = 64'b0000_0000_0001_0001_0101_0000_0100_0100_0001_0010_0101_0101_0010_0000_0000_0000;
        5'd9:  row_bitmap = 64'b0000_0000_0001_0001_0101_0000_0100_0100_0001_0010_0101_0101_0010_0000_0000_0000;
        5'd10: row_bitmap = 64'b0000_0000_0001_0001_0101_0000_0100_0100_0001_0010_0101_0101_0010_0000_0000_0000;
        5'd11: row_bitmap = 64'b0000_0000_0001_0001_0101_1101_1101_1100_0111_0010_0101_0101_0010_0000_0000_0000;
        5'd12: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd13: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd14: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        5'd15: row_bitmap = 64'b0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000_0000;
        default: row_bitmap = 64'b0;
      endcase

      start_banner_pixel = row_bitmap[63 - col];
    end
  endfunction

endmodule