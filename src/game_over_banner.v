module game_over_banner (
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

  localparam [9:0] SPRITE_WIDTH  = 10'd37;
  localparam [9:0] SPRITE_HEIGHT = 10'd9;

  // Shift counts: 2 -> x4, 1 -> x2
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

      if ((x >= left_x) && (x < left_x + (SPRITE_WIDTH  << PIXEL_WIDTH_SHIFT)) &&
          (y >= top_y)  && (y < top_y  + (SPRITE_HEIGHT << PIXEL_HEIGHT_SHIFT)) &&
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
    reg   [36:0] row_bitmap;
    begin
      case (row)
        5'd0:   row_bitmap = 37'b1_1101_1101_0001_0111_0011_1010_1011_1011_0000;
        5'd1:   row_bitmap = 37'b1_0001_0101_1011_0100_0010_1010_1010_0010_1000;
        5'd2:   row_bitmap = 37'b1_0001_0101_0101_0100_0010_1010_1010_0010_1000;
        5'd3:   row_bitmap = 37'b1_0001_0101_0001_0100_0010_1010_1010_0010_1000;
        5'd4:   row_bitmap = 37'b1_0001_1101_0001_0110_0010_1010_1011_0011_0000;
        5'd5:   row_bitmap = 37'b1_0101_0101_0001_0100_0010_1010_1010_0010_1000;
        5'd6:   row_bitmap = 37'b1_0101_0101_0001_0100_0010_1010_1010_0010_1000;
        5'd7:  row_bitmap = 37'b1_0101_0101_0001_0100_0010_1001_0010_0010_1000;
        5'd8:  row_bitmap = 37'b1_1101_0101_0001_0111_0011_1001_0011_1010_1000;
      endcase

      start_banner_pixel = row_bitmap[36 - col];
    end
  endfunction

endmodule