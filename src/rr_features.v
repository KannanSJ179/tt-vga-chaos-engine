`default_nettype none

module rr_features (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire       r_peak,
    output reg  [5:0] rr_interval,
    output reg  [5:0] rr_delta,
    output reg        rr_valid,
    output reg        asystole_flag   
);
    reg [15:0] tick_count;
    reg  [5:0] rr_prev;
    reg        r_peak_prev;
    wire       r_peak_rise = r_peak & ~r_peak_prev;

    wire brd_thresh = tick_count[15] | tick_count[14];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tick_count    <= 16'd0;
            rr_interval   <= 6'd32;
            rr_delta      <= 6'd0;
            rr_prev       <= 6'd32;
            rr_valid      <= 1'b0;
            r_peak_prev   <= 1'b0;
            asystole_flag <= 1'b0;
        end else if (ena) begin
            r_peak_prev <= r_peak;
            rr_valid    <= 1'b0;

            if (r_peak_rise) begin
                rr_interval   <= (tick_count[15:9] > 7'd63)
                                 ? 6'd63 : tick_count[15:9];
                rr_delta      <= (tick_count[15:9] > rr_prev)
                                 ? tick_count[15:9] - rr_prev
                                 : rr_prev - tick_count[15:9];
                rr_prev       <= (tick_count[15:9] > 7'd63)
                                 ? 6'd63 : tick_count[15:9];
                rr_valid      <= 1'b1;
                tick_count    <= 16'd0;
                asystole_flag <= 1'b0;   
            end else begin
                if (tick_count < 16'hFFFF)
                    tick_count <= tick_count + 16'd1;
                if (brd_thresh)
                    asystole_flag <= 1'b1;
            end
        end
    end
endmodule

module spike_encoder (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [5:0] rr_interval,
    input  wire [5:0] rr_delta,
    input  wire       rr_valid,
    output reg  [3:0] spike_interval,
    output reg  [3:0] spike_delta,
    output reg        spike_valid
);
    wire [3:0] enc_interval = 4'd15 - rr_interval[5:2];
    wire [3:0] enc_delta    = (rr_delta > 6'd15) ? 4'd15 : rr_delta[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            spike_interval <= 4'd0;
            spike_delta    <= 4'd0;
            spike_valid    <= 1'b0;
        end else if (ena) begin
            spike_valid <= 1'b0;
            if (rr_valid) begin
                spike_interval <= enc_interval;
                spike_delta    <= enc_delta;
                spike_valid    <= 1'b1;
            end
        end
    end
endmodule

module reservoir (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ena,
    input  wire [3:0]  spike_interval,
    input  wire [3:0]  spike_delta,
    input  wire        spike_valid,
    output wire [10:0] neuron_spikes,   
    output wire        any_spike
);
    wire [3:0] gi = spike_valid ? spike_interval : 4'b0;
    wire [3:0] gd = spike_valid ? spike_delta    : 4'b0;

    wire [10:0] s;
    assign neuron_spikes = s;
    assign any_spike     = |s;

    reg [3:0] spike_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            spike_reg <= 4'b0;
        else if (ena && spike_valid)
            spike_reg <= {s[6], s[4], s[2], s[0]};
    end

    lif_neuron #(.THRESHOLD(8'd5), .WEIGHT(3'd4)) n0  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[0]),                   .spike_out(s[0]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd5)) n1  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[1]),                   .spike_out(s[1]));
    lif_neuron #(.THRESHOLD(8'd6), .WEIGHT(3'd3)) n2  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[2]),                   .spike_out(s[2]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd6)) n3  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[3]),                   .spike_out(s[3]));

    lif_neuron #(.THRESHOLD(8'd3), .WEIGHT(3'd5)) n4  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[0]),                   .spike_out(s[4]));
    lif_neuron #(.THRESHOLD(8'd3), .WEIGHT(3'd4)) n5  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[1]),                   .spike_out(s[5]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd6)) n6  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[2]),                   .spike_out(s[6]));
    lif_neuron #(.THRESHOLD(8'd2), .WEIGHT(3'd3)) n7  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[3] | spike_reg[0]),    .spike_out(s[7]));

    lif_neuron #(.THRESHOLD(8'd5), .WEIGHT(3'd4)) n8  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[0] | spike_reg[1]),    .spike_out(s[8]));
    lif_neuron #(.THRESHOLD(8'd6), .WEIGHT(3'd5)) n9  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[1] | spike_reg[2]),    .spike_out(s[9]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd3)) n10 (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[2] | spike_reg[3]),    .spike_out(s[10]));

endmodule
