module crosshair (
    input  wire       rst_n,
    input  wire       clk,
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

      // Upper half
      if ((y > (pos_y - SPRITE_HEIGHT)) && (y <= pos_y)) begin
        if ((x > (pos_x - SPRITE_WIDTH)) && (x <= pos_x)) begin
          if (crosshair_pixel(y - pos_y + SPRITE_HEIGHT - 1'b1, pos_x - x)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end else if ((x > pos_x) && (x <= pos_x + SPRITE_WIDTH)) begin
          if (crosshair_pixel(y - pos_y + SPRITE_HEIGHT - 1'b1, x - pos_x)) begin
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
          if (crosshair_pixel(pos_y + SPRITE_HEIGHT - y, pos_x - x)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end else if ((x > pos_x) && (x <= pos_x + SPRITE_WIDTH)) begin
          if (crosshair_pixel(pos_y + SPRITE_HEIGHT - y, x - pos_x)) begin
            active <= 1'b1;
            R <= RGB_Color[5:4];
            G <= RGB_Color[3:2];
            B <= RGB_Color[1:0];
          end
        end
      end
    end
  end

  function automatic crosshair_pixel;
    input [3:0] row;
    input [3:0] col;
    begin
      reg [9:0] row_bitmap;
      case (row)
        4'd0: row_bitmap    = 10'b00_0000_0011;
        4'd1: row_bitmap    = 10'b00_0000_0011;
        4'd2: row_bitmap    = 10'b00_0000_0011;
        4'd3: row_bitmap    = 10'b00_0000_0011;
        4'd4: row_bitmap    = 10'b00_0000_0011;
        4'd5: row_bitmap    = 10'b00_0000_0011;
        4'd6: row_bitmap    = 10'b00_0000_0011;
        4'd7: row_bitmap    = 10'b00_0000_0011;
        4'd8: row_bitmap    = 10'b11_1111_1111;
        4'd9: row_bitmap    = 10'b11_1111_1111;
        default: row_bitmap = 10'b00_0000_0000;
      endcase

      crosshair_pixel = row_bitmap[col];
    end
  endfunction

endmodule