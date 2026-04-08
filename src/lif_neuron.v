`default_nettype none

module lif_neuron #(
    parameter THRESHOLD = 8'd5,
    parameter WEIGHT    = 3'd4
) (
    input  wire clk,
    input  wire rst_n,
    input  wire ena,
    input  wire spike_valid,   
    input  wire spike_in,
    output reg  spike_out
);
    reg [7:0] potential;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            potential <= 8'd0;
            spike_out <= 1'b0;
        end else if (ena && spike_valid) begin
            // Heartbeat event: fire-check first, then leak+integrate
            if (potential >= THRESHOLD) begin
                spike_out <= 1'b1;
                potential <= 8'd0;
            end else begin
                spike_out <= 1'b0;
                potential <= (potential >> 1) + (spike_in ? {5'b0, WEIGHT} : 8'd0);
            end
        end
        // No else clause: hold spike_out and potential between heartbeat events.
    end

endmodule
