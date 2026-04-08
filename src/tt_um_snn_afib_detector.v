/*
 * TinyTapeout SNN AFib Detector — Top-level wrapper
 * 10-neuron spiking neural network for real-time arrhythmia detection
 *
 * Module name follows TT convention: tt_um_<project>
 *
 * Pin mapping:
 *   ui_in[0]  — r_peak    (R-peak pulse from ECG front-end)
 *   ui_in[1]  — w_load    (weight-load enable)
 *   ui_in[2]  — w_data    (serial weight data)
 *   ui_in[3]  — w_clk     (weight shift-register clock)
 *   ui_in[7:4] — unused
 *
 *   uo_out[0]   — afib_flag        (1 = AFib detected)
 *   uo_out[1]   — out_valid        (1 = classification ready)
 *   uo_out[2]   — any_spike        (reservoir activity monitor)
 *   uo_out[4:3] — fsm_state[1:0]   (00=LOAD, 01=RUN, 10=OUTPUT)
 *   uo_out[7:5] — confidence_latch (3-bit detection confidence)
 *
 *   uio_*  — unused (active-low, directly tied to 0)
 */

`default_nettype none

module tt_um_snn_afib_detector (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);
    // TT protocol: unused bidirectional pins must be driven low
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;

    wire r_peak = ui_in[0];
    wire w_load = ui_in[1];
    wire w_data = ui_in[2];
    wire w_clk  = ui_in[3];

    wire [5:0]  rr_interval;
    wire [5:0]  rr_delta;
    wire        rr_valid;
    wire [3:0]  spike_interval;
    wire [3:0]  spike_delta;
    wire        spike_valid;
    wire [9:0]  neuron_spikes;
    wire        any_spike;
    wire [7:0]  score;
    wire        score_valid;
    wire        afib_flag;
    wire        out_valid;
    wire [1:0]  fsm_state;
    wire [2:0]  confidence;
    wire [2:0]  confidence_latch;

    rr_features u_rr_features (
        .clk        (clk),
        .rst_n      (rst_n),
        .ena        (ena),
        .r_peak     (r_peak),
        .rr_interval(rr_interval),
        .rr_delta   (rr_delta),
        .rr_valid   (rr_valid)
    );

    spike_encoder u_spike_enc (
        .clk           (clk),
        .rst_n         (rst_n),
        .ena           (ena),
        .rr_interval   (rr_interval),
        .rr_delta      (rr_delta),
        .rr_valid      (rr_valid),
        .spike_interval(spike_interval),
        .spike_delta   (spike_delta),
        .spike_valid   (spike_valid)
    );

    reservoir u_reservoir (
        .clk           (clk),
        .rst_n         (rst_n),
        .ena           (ena),
        .spike_interval(spike_interval),
        .spike_delta   (spike_delta),
        .spike_valid   (spike_valid),
        .neuron_spikes (neuron_spikes),
        .any_spike     (any_spike)
    );

    readout u_readout (
        .clk             (clk),
        .rst_n           (rst_n),
        .ena             (ena),
        .w_load          (w_load),
        .w_data          (w_data),
        .w_clk           (w_clk),
        .neuron_spikes   (neuron_spikes),
        .spike_valid     (spike_valid),
        .score           (score),
        .score_valid     (score_valid),
        .afib_flag       (afib_flag),
        .out_valid       (out_valid),
        .fsm_state       (fsm_state),
        .confidence      (confidence),
        .confidence_latch(confidence_latch)
    );

    assign uo_out[0]   = afib_flag;
    assign uo_out[1]   = out_valid;
    assign uo_out[2]   = any_spike;
    assign uo_out[3]   = fsm_state[0];
    assign uo_out[4]   = fsm_state[1];
    assign uo_out[7:5] = confidence_latch;

endmodule
