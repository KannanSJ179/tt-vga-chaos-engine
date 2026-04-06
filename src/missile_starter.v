module missile_starter(
  input wire rst_n,
  input wire clk,
  output wire [9:0] start_x,
  output wire [3:0] coefficient_x,
  output wire [3:0] coefficient_y
);
  localparam LEFT_LEFT_QUARTER   = 10'd80;
  localparam LEFT_QUARTER        = 10'd160;
  localparam LEFT_RIGHT_QUARTER  = 10'd240;
  localparam RIGHT_LEFT_QUARTER  = 10'd400;
  localparam RIGHT_QUARTER       = 10'd480;
  localparam RIGHT_RIGHT_QUARTER = 10'd560;

  reg [9:0] my_x;
  reg [3:0] c_x;
  reg [3:0] c_y;

  assign start_x       = my_x;
  assign coefficient_x = c_x;
  assign coefficient_y = c_y;

  always @(posedge clk) begin
    if (!rst_n) begin
      my_x <= 0;
      c_x  <= 1;
      c_y  <= 2;
    end else begin
      if (my_x + 1'b1 > 10'd640)
        my_x <= 0;
      else
        my_x <= my_x + 1'b1;

      if (my_x <= LEFT_LEFT_QUARTER) begin
        c_x <= 2;
        c_y <= 3;
      end

      if (my_x > LEFT_LEFT_QUARTER && my_x <= LEFT_QUARTER) begin
        c_x <= 1;
        c_y <= 2;
      end

      if (my_x > LEFT_QUARTER && my_x <= LEFT_RIGHT_QUARTER) begin
        c_x <= 1;
        c_y <= 3;
      end

      if (my_x > LEFT_RIGHT_QUARTER && my_x <= RIGHT_LEFT_QUARTER) begin
        c_x <= 0;
        c_y <= 2;
      end

      if (my_x > RIGHT_LEFT_QUARTER && my_x <= RIGHT_QUARTER) begin
        c_x <= 1;
        c_y <= 3;
      end

      if (my_x > RIGHT_QUARTER && my_x <= RIGHT_RIGHT_QUARTER) begin
        c_x <= 1;
        c_y <= 2;
      end

      if (my_x > RIGHT_RIGHT_QUARTER) begin
        c_x <= 2;
        c_y <= 3;
      end
    end
  end

endmodule
