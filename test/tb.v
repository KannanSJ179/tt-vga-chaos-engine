`timescale 1ns/1ps

module tb;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena, clk, rst_n;

    `define AFIB_FLAG  uo_out[0]
    `define VALID      uo_out[1]
    `define SPIKE_MON  uo_out[2]
    `define FSM_STATE  uo_out[4:3]
    `define CONFIDENCE uo_out[7:5]

    tt_um_snn_afib_detector dut (
        .ui_in(ui_in), .uo_out(uo_out),
        .uio_in(uio_in), .uio_out(uio_out), .uio_oe(uio_oe),
        .ena(ena), .clk(clk), .rst_n(rst_n)
    );

    initial clk = 0;
    always #50 clk = ~clk;   // 10 MHz, 100 ns period

    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

    //  Persistent spike-activity latch 
    reg spike_seen;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)          spike_seen <= 1'b0;
        else if (`SPIKE_MON) spike_seen <= 1'b1;
    end

    //  Tasks 
    task wait_clks;
        input integer n;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) @(posedge clk);
        end
    endtask

    task send_r_peak;
        begin
            @(posedge clk); #1; ui_in[0] = 1;
            @(posedge clk); #1; ui_in[0] = 0;
        end
    endtask

    task send_beat_after;
        input integer ticks;
        begin
            wait_clks(ticks);
            send_r_peak();
        end
    endtask

    task load_weights;
        input [29:0] weights;
        integer i;
        begin
            @(posedge clk); #1;
            ui_in[1] = 1; ui_in[2] = 0; ui_in[3] = 0;
            for (i = 29; i >= 0; i = i - 1) begin
                @(posedge clk); #1;
                ui_in[2] = weights[i];
                ui_in[3] = 1;
                @(posedge clk); #1;
                ui_in[3] = 0;
            end
            @(posedge clk); #1;
            ui_in[1] = 0;
            wait_clks(5);
            $display("[TB] Weights loaded. FSM=%b", `FSM_STATE);
        end
    endtask

    //  Weight constants (10-neuron, 30-bit) 
    //   n7-9 (recurrent+feedback): +2 = 3'b010
    //   n3-6 (delta stream):       +3 = 3'b011
    //   n0-2 (interval stream):    -3, -1, -1 = 3'b101, 3'b111, 3'b111
    localparam [29:0] AFIB_WEIGHTS = 30'h124DB77F;

    integer pass_count, fail_count;

    initial begin
        ui_in      = 8'b0;
        uio_in     = 8'b0;
        ena        = 1;
        rst_n      = 0;
        pass_count = 0;
        fail_count = 0;

        $display("================================================");
        $display("  TT SNN AFib Detector — Verification TB v4");
        $display("  10-neuron | FAST_THRESH=16 | SLOW_THRESH=32");
        $display("================================================");

        wait_clks(5); rst_n = 1; wait_clks(3);

        //  T0: TT bidirectional port constraint 
        if (uio_out === 8'b0 && uio_oe === 8'b0) begin
            $display("[PASS] T0: uio_out=0 uio_oe=0");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T0: uio_out=%b uio_oe=%b (expected both 0)",
                     uio_out, uio_oe);
            fail_count = fail_count + 1;
        end

        //  T1: FSM starts in LOAD 
        wait_clks(2);
        if (`FSM_STATE === 2'b00) begin
            $display("[PASS] T1: FSM starts in LOAD (00)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T1: FSM=%b expected 00", `FSM_STATE);
            fail_count = fail_count + 1;
        end

        //  T2: Weight load → FSM moves to RUN 
        $display("[INFO] Loading signed weights...");
        load_weights(AFIB_WEIGHTS);
        if (`FSM_STATE === 2'b01) begin
            $display("[PASS] T2: FSM moved to RUN (01) after weight load");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T2: FSM=%b expected 01", `FSM_STATE);
            fail_count = fail_count + 1;
        end

        //  T3: Normal sinus rhythm (32 beats = 2 full slow windows) 
        // Steady 7000 ticks → rr_delta ≈ 0 → delta neurons silent
        // With FAST_THRESH=16, accumulator should stay well below threshold
        $display("[INFO] T3: Sending 32 normal beats (7000 ticks each)...");
        begin : norm_loop
            integer i;
            for (i = 0; i < 32; i = i + 1) send_beat_after(7000);
        end
        wait_clks(50);
        $display("[INFO] T3: afib=%b valid=%b confidence=%b",
                 `AFIB_FLAG, `VALID, `CONFIDENCE);

        if (`VALID === 1'b1) begin
            $display("[PASS] T3a: out_valid asserted — slow window closed");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T3a: out_valid=0 — slow window never closed");
            fail_count = fail_count + 1;
        end

        if (`AFIB_FLAG === 1'b0) begin
            $display("[PASS] T3b: Normal rhythm correctly classified (afib=0)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T3b: False positive — afib=1 on normal rhythm");
            fail_count = fail_count + 1;
        end

        //  Reset between T3 and T4 for clean accumulator state 
        $display("[INFO] Reset + reload for clean T4 window...");
        rst_n = 0; wait_clks(3); rst_n = 1; wait_clks(3);
        load_weights(AFIB_WEIGHTS);

        //  T4: AFib rhythm (32 irregular beats) 
        // Alternating short/long intervals → high rr_delta → delta neurons fire
        // Expected: accum blows past threshold → afib_flag=1
        $display("[INFO] T4: Sending 32 irregular AFib beats...");

        // Window 1 (beats 1–16)
        send_beat_after(2500);  send_beat_after(9500);
        send_beat_after(3000);  send_beat_after(8800);
        send_beat_after(2200);  send_beat_after(9200);
        send_beat_after(3500);  send_beat_after(8000);
        send_beat_after(2800);  send_beat_after(9800);
        send_beat_after(2000);  send_beat_after(10000);
        send_beat_after(3200);  send_beat_after(8500);
        send_beat_after(2600);  send_beat_after(9100);

        // Window 2 (beats 17–32)
        send_beat_after(3100);  send_beat_after(8200);
        send_beat_after(2400);  send_beat_after(9600);
        send_beat_after(2700);  send_beat_after(9300);
        send_beat_after(3300);  send_beat_after(8700);
        send_beat_after(2100);  send_beat_after(9700);
        send_beat_after(3400);  send_beat_after(8100);
        send_beat_after(2900);  send_beat_after(9400);

        wait_clks(100);
        $display("[INFO] T4: afib=%b valid=%b confidence=%b spike_seen=%b",
                 `AFIB_FLAG, `VALID, `CONFIDENCE, spike_seen);

        if (`AFIB_FLAG === 1'b1) begin
            $display("[PASS] T4a: AFib correctly detected (afib=1)");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T4a: AFib not detected");
            fail_count = fail_count + 1;
        end

        if (spike_seen) begin
            $display("[PASS] T4b: Reservoir neurons fired during AFib sequence");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T4b: No reservoir spikes seen");
            fail_count = fail_count + 1;
        end

        //  T5: confidence_latch in AFib range 
        if (`CONFIDENCE >= 3'b101) begin
            $display("[PASS] T5: confidence_latch in AFib range = %b", `CONFIDENCE);
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T5: confidence_latch too low = %b (expected >=101)",
                     `CONFIDENCE);
            fail_count = fail_count + 1;
        end

        //  T6: Reset clears all outputs 
        rst_n = 0; wait_clks(3);
        if (`AFIB_FLAG === 1'b0 && `VALID === 1'b0 && `FSM_STATE === 2'b00) begin
            $display("[PASS] T6: Reset clears afib_flag, out_valid, FSM=LOAD");
            pass_count = pass_count + 1;
        end else begin
            $display("[FAIL] T6: afib=%b valid=%b fsm=%b after reset",
                     `AFIB_FLAG, `VALID, `FSM_STATE);
            fail_count = fail_count + 1;
        end
        rst_n = 1;

        //  Summary 
        $display("================================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  %0d TEST(S) FAILED — see above", fail_count);
        $display("  Waveform: tb.vcd");
        $display("================================================");
        #1000; $finish;
    end

    initial begin
        #500_000_000;
        $display("[TIMEOUT] Simulation exceeded 500 ms budget");
        $finish;
    end

endmodule
