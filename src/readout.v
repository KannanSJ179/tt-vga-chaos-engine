`default_nettype none

module readout (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ena,
    input  wire        w_load,
    input  wire        w_data,
    input  wire        w_clk,
    input  wire [10:0] neuron_spikes,
    input  wire        spike_valid,
    output reg         afib_flag,
    output reg         out_valid,
    output reg  [1:0]  fsm_state,
    output wire [2:0]  confidence,
    output reg  [2:0]  confidence_latch
);
    localparam ULTRA_WINDOW = 3'd4;
    localparam FAST_WINDOW  = 4'd8;
    localparam SLOW_WINDOW  = 5'd16;

    localparam signed [8:0]  ULTRA_THRESH = -9'sd1;
    localparam signed [8:0]  FAST_THRESH  = -9'sd1;
    localparam signed [9:0]  SLOW_THRESH  = -10'sd2;

    localparam LOAD   = 2'b00;
    localparam RUN    = 2'b01;
    localparam ACCUM  = 2'b10;
    localparam OUTPUT = 2'b11;

    reg [32:0] weight_sr;
    reg        w_clk_prev;
    reg        w_load_seen;

    // Sequential accumulation registers
    reg signed [12:0] accum_reg;
    reg [3:0]         neuron_idx;
    reg [10:0]        spike_buffer;

    // Current weight being processed (sign-extended to 9 bits)
    wire [2:0]  curr_w_raw = weight_sr[2:0];
    wire signed [8:0] curr_ws  = {{6{curr_w_raw[2]}}, curr_w_raw};

    reg signed [8:0]  accum_ultra;
    reg               afib_ultra;

    reg signed [8:0]  accum_fast;
    reg [3:0]         beat_fast;
    reg               afib_fast;
    reg signed [8:0]  accum_fast_snap;

    reg signed [9:0]  accum_slow;
    reg [4:0]         beat_slow;
    reg               afib_slow;

    wire ultra_close = (beat_fast == ULTRA_WINDOW - 1) |
                       (beat_fast == FAST_WINDOW  - 1);

    assign confidence =
        (accum_fast_snap >= FAST_THRESH + 9'sd8) ? 3'b111 :
        (accum_fast_snap >= FAST_THRESH + 9'sd4) ? 3'b110 :
        (accum_fast_snap >= FAST_THRESH)          ? 3'b101 :
        (accum_fast_snap <= FAST_THRESH - 9'sd8) ? 3'b000 :
        (accum_fast_snap <= FAST_THRESH - 9'sd4) ? 3'b001 : 3'b010;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            weight_sr        <= 33'b0;
            w_clk_prev       <= 1'b0;
            w_load_seen      <= 1'b0;
            accum_reg        <= 13'sd0;
            neuron_idx       <= 4'd0;
            spike_buffer     <= 11'b0;
            accum_ultra      <= 9'sd0;
            accum_fast       <= 9'sd0;
            accum_slow       <= 10'sd0;
            accum_fast_snap  <= 9'sd0;
            beat_fast        <= 4'd0;
            beat_slow        <= 5'd0;
            afib_ultra       <= 1'b0;
            afib_fast        <= 1'b0;
            afib_slow        <= 1'b0;
            afib_flag        <= 1'b0;
            out_valid        <= 1'b0;
            confidence_latch <= 3'b010;
            fsm_state        <= LOAD;
        end else if (ena) begin
            w_clk_prev  <= w_clk;
            case (fsm_state)
                LOAD: begin
                    out_valid <= 1'b0;
                    if (w_load)
                        w_load_seen <= 1'b1;
                    if (w_clk & ~w_clk_prev)
                        weight_sr <= {weight_sr[31:0], w_data};
                    if (w_load_seen && !w_load) begin
                        fsm_state   <= RUN;
                        accum_ultra <= 9'sd0;
                        accum_fast  <= 9'sd0;
                        accum_slow  <= 10'sd0;
                        beat_fast   <= 4'd0;
                        beat_slow   <= 5'd0;
                        w_load_seen <= 1'b0;
                    end
                end

                RUN: begin
                    if (w_load) begin
                        fsm_state <= LOAD;
                    end else if (spike_valid) begin
                        accum_reg    <= 13'sd0;
                        neuron_idx   <= 4'd0;
                        spike_buffer <= neuron_spikes;
                        fsm_state    <= ACCUM;
                    end
                end

                ACCUM: begin
                    if (neuron_idx < 4'd11) begin
                        // Accumulate current bit
                        if (spike_buffer[0])
                            accum_reg <= accum_reg + curr_ws;
                        // Rotate for next bit
                        weight_sr    <= {weight_sr[2:0], weight_sr[32:3]};
                        spike_buffer <= {1'b0, spike_buffer[10:1]};
                        neuron_idx   <= neuron_idx + 4'd1;
                    end else begin
                        // Sequential sum complete. Perform window updates.
                        // Ultra window logic
                        if (ultra_close) begin
                            afib_ultra  <= (accum_ultra + accum_reg[8:0] > ULTRA_THRESH);
                            accum_ultra <= 9'sd0;
                        end else begin
                            accum_ultra <= accum_ultra + accum_reg[8:0];
                        end

                        // Fast window logic
                        if (beat_fast == FAST_WINDOW - 1) begin
                            afib_fast       <= (accum_fast + accum_reg[8:0] > FAST_THRESH);
                            accum_fast_snap <= accum_fast + accum_reg[8:0];
                            accum_fast      <= 9'sd0;
                            beat_fast       <= 4'd0;
                        end else begin
                            accum_fast      <= accum_fast + accum_reg[8:0];
                            beat_fast       <= beat_fast + 4'd1;
                        end

                        // Slow window logic
                        if (beat_slow == SLOW_WINDOW - 1) begin
                            afib_slow  <= (accum_slow + accum_reg[9:0] > SLOW_THRESH);
                            accum_slow <= 10'sd0;
                            beat_slow  <= 5'd0;
                            fsm_state  <= OUTPUT;
                        end else begin
                            accum_slow <= accum_slow + accum_reg[9:0];
                            beat_slow  <= beat_slow + 5'd1;
                            fsm_state  <= RUN;
                        end
                    end
                end

                OUTPUT: begin
                    confidence_latch <= confidence;
                    afib_flag   <= (afib_ultra & afib_fast)  |
                                   (afib_fast  & afib_slow)  |
                                   (afib_ultra & afib_slow);
                    out_valid   <= 1'b1;
                    fsm_state   <= RUN;
                end
                default: fsm_state <= LOAD;
            endcase
        end
    end
endmodule
