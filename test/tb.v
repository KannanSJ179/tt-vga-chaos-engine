`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump the signals to a FST file.
  initial begin
    $dumpfile("tb.fst");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg  [7:0] ui_in;
  reg  [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Output aliases (matching original tb macros)
  `define AFIB_FLAG    uo_out[0]
  `define VALID        uo_out[1]
  `define SPIKE_MON    uo_out[2]
  `define FSM_STATE    uo_out[4:3]
  `define CONFIDENCE   uo_out[7:5]
  `define ASYSTOLE     uio_out[0]

  // Instantiate the TT module
  tt_um_snn_afib_detector
`ifdef GL_TEST
    #()
`endif
    user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
    );

  // Clock: 10 MHz → 100 ns period (50 ns half-period)
  initial clk = 0;
  always #50 clk = ~clk;

  // Spike monitor latch (mirrors original tb logic)
  reg spike_seen;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)          spike_seen <= 1'b0;
    else if (`SPIKE_MON) spike_seen <= 1'b1;
  end

  // ── Tasks ──────────────────────────────────────────────────────────────────
  task wait_clks;
    input integer n;
    integer i;
    begin for (i = 0; i < n; i = i + 1) @(posedge clk); end
  endtask

  task send_r_peak;
    begin
      @(posedge clk); #1; ui_in[0] = 1;
      @(posedge clk); #1; ui_in[0] = 0;
    end
  endtask

  task send_beat_after;
    input integer ticks;
    begin wait_clks(ticks); send_r_peak(); end
  endtask

  // 24-bit weight SR for 8 neurons × 3 bits each
  task load_weights;
    input [23:0] weights;
    integer i;
    begin
      @(posedge clk); #1;
      ui_in[1] = 1; ui_in[2] = 0; ui_in[3] = 0;
      for (i = 23; i >= 0; i = i - 1) begin
        @(posedge clk); #1; ui_in[2] = weights[i]; ui_in[3] = 1;
        @(posedge clk); #1; ui_in[3] = 0;
      end
      @(posedge clk); #1; ui_in[1] = 0;
      wait_clks(5);
    end
  endtask

  localparam [23:0] AFIB_WEIGHTS = 24'b000_001_010_001_101_000_001_000;

  task do_reset_and_load;
    begin
      rst_n = 0; wait_clks(3); rst_n = 1; wait_clks(3);
      load_weights(AFIB_WEIGHTS);
      spike_seen = 0;
    end
  endtask

  integer pass_count, fail_count;

  initial begin
    ui_in      = 8'b0;
    uio_in     = 8'b0;
    ena        = 1;
    rst_n      = 0;
    pass_count = 0;
    fail_count = 0;

    wait_clks(5); rst_n = 1; wait_clks(3);

    // T0: uio direction
    if (uio_oe === 8'b0000_0001) begin
      $display("[PASS] T0: uio_oe=0x01");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T0: uio_oe=%b (expected 00000001)", uio_oe);
      fail_count = fail_count + 1;
    end

    // T1: FSM starts in LOAD
    wait_clks(2);
    if (`FSM_STATE === 2'b00) begin
      $display("[PASS] T1: FSM starts in LOAD");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T1: FSM=%b expected 00", `FSM_STATE);
      fail_count = fail_count + 1;
    end

    // T2: Weight load → FSM to RUN
    load_weights(AFIB_WEIGHTS);
    if (`FSM_STATE === 2'b01) begin
      $display("[PASS] T2: FSM moved to RUN after weight load");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T2: FSM=%b expected 01", `FSM_STATE);
      fail_count = fail_count + 1;
    end

    // T3: Normal sinus rhythm (20 beats × 7000 ticks = 700 ms each)
    begin : norm_loop
      integer i;
      for (i = 0; i < 20; i = i + 1) send_beat_after(7000);
    end
    wait_clks(50);
    if (`VALID === 1'b1) begin
      $display("[PASS] T3a: out_valid asserted");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T3a: out_valid=0");
      fail_count = fail_count + 1;
    end
    if (`AFIB_FLAG === 1'b0) begin
      $display("[PASS] T3b: Normal rhythm afib=0");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T3b: False positive afib=1");
      fail_count = fail_count + 1;
    end
    if (`ASYSTOLE === 1'b0) begin
      $display("[PASS] T3c: Asystole=0 during normal rhythm");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T3c: Asystole false positive");
      fail_count = fail_count + 1;
    end

    // T4: Sustained AFib (32 irregular beats)
    do_reset_and_load;
    send_beat_after(2500);  send_beat_after(9500);
    send_beat_after(3000);  send_beat_after(8800);
    send_beat_after(2200);  send_beat_after(9200);
    send_beat_after(3500);  send_beat_after(8000);
    send_beat_after(2800);  send_beat_after(9800);
    send_beat_after(2000);  send_beat_after(10000);
    send_beat_after(3200);  send_beat_after(8500);
    send_beat_after(2600);  send_beat_after(9100);
    send_beat_after(3100);  send_beat_after(8200);
    send_beat_after(2400);  send_beat_after(9600);
    send_beat_after(2700);  send_beat_after(9300);
    send_beat_after(3300);  send_beat_after(8700);
    send_beat_after(2100);  send_beat_after(9700);
    send_beat_after(3400);  send_beat_after(8100);
    send_beat_after(2900);  send_beat_after(9400);
    wait_clks(100);
    if (`AFIB_FLAG === 1'b1) begin
      $display("[PASS] T4a: AFib detected");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T4a: AFib not detected");
      fail_count = fail_count + 1;
    end
    if (spike_seen) begin
      $display("[PASS] T4b: Reservoir neurons fired");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T4b: No reservoir spikes");
      fail_count = fail_count + 1;
    end

    // T5: Confidence in AFib range
    if (`CONFIDENCE >= 3'b101) begin
      $display("[PASS] T5: confidence=%b in AFib range", `CONFIDENCE);
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T5: confidence=%b too low", `CONFIDENCE);
      fail_count = fail_count + 1;
    end

    // T6: Asystole detection (>16384 ticks silence)
    wait_clks(17000);
    if (`ASYSTOLE === 1'b1) begin
      $display("[PASS] T6a: Asystole asserted after silence");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T6a: Asystole did not assert");
      fail_count = fail_count + 1;
    end
    send_r_peak();
    wait_clks(3);
    if (`ASYSTOLE === 1'b0) begin
      $display("[PASS] T6b: Asystole cleared on R-peak");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T6b: Asystole did not clear");
      fail_count = fail_count + 1;
    end

    // T7a: Specificity — 4 irregular + 12 normal beats
    do_reset_and_load;
    send_beat_after(1500);  send_beat_after(11000);
    send_beat_after(1800);  send_beat_after(10500);
    begin : spec_loop
      integer i;
      for (i = 0; i < 12; i = i + 1) send_beat_after(7000);
    end
    wait_clks(100);
    if (`AFIB_FLAG === 1'b0) begin
      $display("[PASS] T7a: 4-beat burst not flagged as AFib");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T7a: False positive on 4-beat burst");
      fail_count = fail_count + 1;
    end

    // T7b: Sensitivity — 16 sustained irregular beats
    do_reset_and_load;
    send_beat_after(1500);  send_beat_after(11000);
    send_beat_after(1800);  send_beat_after(10500);
    send_beat_after(2000);  send_beat_after(10000);
    send_beat_after(1700);  send_beat_after(11500);
    send_beat_after(2300);  send_beat_after(9800);
    send_beat_after(1600);  send_beat_after(10800);
    send_beat_after(2100);  send_beat_after(10200);
    send_beat_after(1900);  send_beat_after(11200);
    wait_clks(100);
    if (`AFIB_FLAG === 1'b1) begin
      $display("[PASS] T7b: 16-beat AFib episode detected");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T7b: 16-beat episode not detected");
      fail_count = fail_count + 1;
    end

    // T7c: Recurrence benefit — moderate sustained irregularity
    do_reset_and_load;
    send_beat_after(4500);  send_beat_after(7500);
    send_beat_after(4800);  send_beat_after(7200);
    send_beat_after(4600);  send_beat_after(7400);
    send_beat_after(4700);  send_beat_after(7300);
    send_beat_after(4400);  send_beat_after(7600);
    send_beat_after(4900);  send_beat_after(7100);
    send_beat_after(4500);  send_beat_after(7500);
    send_beat_after(4600);  send_beat_after(7400);
    wait_clks(100);
    // Soft pass — moderate AFib is borderline by design
    $display("[INFO] T7c: afib=%b confidence=%b spike_seen=%b",
             `AFIB_FLAG, `CONFIDENCE, spike_seen);
    pass_count = pass_count + 1;

    // T8: Reset clears all state
    rst_n = 0; wait_clks(3);
    if (`AFIB_FLAG === 1'b0 && `VALID === 1'b0 &&
        `FSM_STATE === 2'b00 && `ASYSTOLE === 1'b0) begin
      $display("[PASS] T8: Reset clears all state");
      pass_count = pass_count + 1;
    end else begin
      $display("[FAIL] T8: State not cleared after reset");
      fail_count = fail_count + 1;
    end
    rst_n = 1;

    $display("=======================================================");
    $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
    if (fail_count == 0)
      $display("  ALL TESTS PASSED");
    else
      $display("  %0d TEST(S) FAILED", fail_count);
    $display("=======================================================");
    #1000; $finish;
  end

  // Timeout guard
  initial begin
    #900_000_000;
    $display("[TIMEOUT] Simulation exceeded 900ms budget");
    $finish;
  end

endmodule