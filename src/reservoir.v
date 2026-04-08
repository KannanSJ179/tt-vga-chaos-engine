`default_nettype none

module reservoir (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        ena,
    input  wire [3:0]  spike_interval,
    input  wire [3:0]  spike_delta,
    input  wire        spike_valid,
    output wire [9:0]  neuron_spikes,   
    output wire        any_spike
);

    wire [3:0] gi = spike_valid ? spike_interval : 4'b0;
    wire [3:0] gd = spike_valid ? spike_delta    : 4'b0;

    wire [9:0] s;
    assign neuron_spikes = s;
    assign any_spike     = |s;

    //  Delayed spike feedback register 
   
    reg [3:0] spike_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            spike_reg <= 4'b0;
        else if (ena && spike_valid)
            spike_reg <= {s[5], s[3], s[2], s[0]};
    end

    //  Neurons 0-2: RR interval input stream 
    lif_neuron #(.THRESHOLD(8'd5), .WEIGHT(3'd4)) n0  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[0]),                   .spike_out(s[0]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd5)) n1  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[1]),                   .spike_out(s[1]));
    lif_neuron #(.THRESHOLD(8'd6), .WEIGHT(3'd3)) n2  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[2]),                   .spike_out(s[2]));

    //  Neurons 3-6: HRV delta input stream 

    lif_neuron #(.THRESHOLD(8'd3), .WEIGHT(3'd5)) n3  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[0]),                   .spike_out(s[3]));
    lif_neuron #(.THRESHOLD(8'd3), .WEIGHT(3'd4)) n4  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[1]),                   .spike_out(s[4]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd6)) n5  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[2]),                   .spike_out(s[5]));
    // n6 gets gd[3] OR delayed n0 spike — first recurrent connection
    lif_neuron #(.THRESHOLD(8'd2), .WEIGHT(3'd3)) n6  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gd[3] | spike_reg[0]),    .spike_out(s[6]));

    //  Neurons 7-9: recurrent mixing with true temporal feedback 
    
    lif_neuron #(.THRESHOLD(8'd5), .WEIGHT(3'd4)) n7  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[0] | spike_reg[1]),    .spike_out(s[7]));
    lif_neuron #(.THRESHOLD(8'd6), .WEIGHT(3'd5)) n8  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[1] | spike_reg[2]),    .spike_out(s[8]));
    lif_neuron #(.THRESHOLD(8'd4), .WEIGHT(3'd3)) n9  (.clk(clk),.rst_n(rst_n),.ena(ena),.spike_valid(spike_valid),.spike_in(gi[2] | spike_reg[3]),    .spike_out(s[9]));

endmodule
