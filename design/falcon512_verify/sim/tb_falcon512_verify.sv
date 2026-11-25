///////////////////////////////////////////////////////
// Module : tb_falcon512_verify
// Author   : desktop-ifrf24e\najam
// Description: Self-checking bench for the Falcon-512 verify core. Time-domain
//              polynomials are encoded into the u/h streams with a local NTT,
//              while the expected s1 is computed independently by a schoolbook
//              negacyclic multiply or chosen as a literal sparse vector. Every
//              output beat, the 40-bit norm and the inclusive verdict are
//              compared in one run; one mismatch counter produces the sole
//              RESULT token and a bounded watchdog ends a stalled test. The
//              optional +REGRESS mode adds accept-path, dense-boundary, seed
//              sweep and backpressure-pattern runs without touching the DUT.
///////////////////////////////////////////////////////
`default_nettype none

module tb_falcon512_verify;
  import falcon512_pkg::*;

  // ---------------------------------------------------------------------------
  // 1. Clock, DUT interface and global error state
  // ---------------------------------------------------------------------------
  logic clk = 1'b0;
  logic rst_n = 1'b0;

  logic         u_tvalid = 1'b0;
  logic         u_tready;
  logic [15:0]  u_tdata  = 16'd0;
  logic         h_tvalid = 1'b0;
  logic         h_tready;
  logic [15:0]  h_tdata  = 16'd0;
  logic         s2_tvalid = 1'b0;
  logic         s2_tready;
  logic [15:0]  s2_tdata  = 16'd0;

  logic         m_tvalid;
  logic         m_tready = 1'b1;
  logic [15:0]  m_tdata;
  logic         m_tlast;
  logic         verify_valid;
  logic         verify_accept;
  logic [39:0]  verify_norm_sq;

  int mismatch = 0;
  int case_id = 0;
  int cycles = 0;
  int seed_base_q = 0;
  int seed_count_q = 1;
  int bp_mode_q = 0;
  int regress_q = 0;
  int cycle_q = 0;
  int last_input_cycle_q = 0;
  int verdict_cycle_q = 0;
  int last_latency_q = 0;

  falcon512_verify dut (
    .axi_st_clk      (clk           ),
    .axi_st_areset_n (rst_n         ),
    .u_tvalid        (u_tvalid      ),
    .u_tready        (u_tready      ),
    .u_tdata         (u_tdata       ),
    .h_tvalid        (h_tvalid      ),
    .h_tready        (h_tready      ),
    .h_tdata         (h_tdata       ),
    .s2_tvalid       (s2_tvalid     ),
    .s2_tready       (s2_tready     ),
    .s2_tdata        (s2_tdata      ),
    .m_tvalid        (m_tvalid      ),
    .m_tready        (m_tready      ),
    .m_tdata         (m_tdata       ),
    .m_tlast         (m_tlast       ),
    .verify_valid    (verify_valid  ),
    .verify_accept   (verify_accept ),
    .verify_norm_sq  (verify_norm_sq)
  );

  always #5 clk = ~clk;

  // The checker reads a one-cycle delayed copy of the output bus. That copy
  // holds the exact values present at the previous accepting edge, independent
  // of NBA ordering and of backpressure on m_tready.
  logic        hs_d1 = 1'b0;
  logic        last_d1 = 1'b0;
  logic        ver_d1 = 1'b0;
  logic [15:0] data_d1 = 16'd0;

  always_ff @(posedge clk) begin
    hs_d1   <= m_tvalid && m_tready;
    data_d1 <= m_tdata;
    last_d1 <= m_tlast;
    ver_d1  <= verify_valid;
  end

  always_ff @(posedge clk) begin
    if (rst_n) cycle_q <= cycle_q + 1;
    else       cycle_q <= 0;
  end

  // ---------------------------------------------------------------------------
  // 2. Reference storage
  // ---------------------------------------------------------------------------
  logic [15:0] u_time_a  [0:N-1];
  logic [15:0] h_time_a  [0:N-1];
  logic [15:0] s2_time_a [0:N-1];
  logic [15:0] exp_s1_a  [0:N-1];
  logic [15:0] prod_a    [0:N-1];
  logic [15:0] u_ntt_a   [0:N-1];
  logic [15:0] h_ntt_a   [0:N-1];
  logic [15:0] work_a    [0:N-1];

  logic [39:0] exp_norm_q;
  logic        exp_accept_q;
  logic [31:0] lfsr_q = 32'h1234_5678;

  // ---------------------------------------------------------------------------
  // 3. Local NTT used only to encode the input streams
  // ---------------------------------------------------------------------------
  function automatic logic [8:0] tb_bitrev(input logic [8:0] idx);
    logic [8:0] rev;
    for (int i = 0; i < LOG2_N; i++) begin
      rev[i] = idx[LOG2_N - 1 - i];
    end
    return rev;
  endfunction : tb_bitrev

  task automatic tb_copy_to_work(input int sel);
    for (int i = 0; i < N; i++) begin
      case (sel)
        0: work_a[i] = u_time_a[i];
        1: work_a[i] = h_time_a[i];
        default: work_a[i] = 16'd0;
      endcase
    end
  endtask : tb_copy_to_work

  task automatic tb_copy_from_work(input int sel);
    for (int i = 0; i < N; i++) begin
      case (sel)
        0: u_ntt_a[i] = work_a[i];
        1: h_ntt_a[i] = work_a[i];
        default: begin end
      endcase
    end
  endtask : tb_copy_from_work

  task automatic tb_ntt_fwd();
    int stage;
    int length;
    int half;
    int groups;
    int group;
    int k;
    int idx0;
    int idx1;
    int j;
    logic [15:0] w;
    logic [15:0] wlen;
    logic [15:0] tmp;
    logic [15:0] aa;
    logic [15:0] bb;
    logic [15:0] swap;

    w = 16'd1;
    for (int i = 0; i < N; i++) begin
      work_a[i] = f_mod_mul(work_a[i], w);
      w = f_mod_mul(w, PSI);
    end

    for (int i = 1; i < N; i++) begin
      j = tb_bitrev(i[8:0]);
      if (i < j) begin
        swap = work_a[i];
        work_a[i] = work_a[j];
        work_a[j] = swap;
      end
    end

    for (stage = 1; stage <= LOG2_N; stage++) begin
      length = 1 << stage;
      half   = length >> 1;
      groups = N >> stage;
      wlen   = f_stage_root_fwd(stage);
      for (group = 0; group < groups; group++) begin
        w = 16'd1;
        for (k = 0; k < half; k++) begin
          idx0 = group * length + k;
          idx1 = idx0 + half;
          tmp  = f_mod_mul(work_a[idx1], w);
          aa   = work_a[idx0];
          bb   = work_a[idx1];
          work_a[idx0] = f_mod_add(aa, tmp);
          work_a[idx1] = f_mod_sub(aa, tmp);
          w = f_mod_mul(w, wlen);
        end
      end
    end
  endtask : tb_ntt_fwd

  // ---------------------------------------------------------------------------
  // 4. Independent schoolbook reference for s2*h
  // ---------------------------------------------------------------------------
  task automatic tb_schoolbook();
    longint acc;
    longint term;
    integer s2v;
    int k;
    int sign;

    for (int idx = 0; idx < N; idx++) begin
      prod_a[idx] = 16'd0;
    end

    for (int i = 0; i < N; i++) begin
      s2v = $signed(s2_time_a[i]);
      if (s2v != 0) begin
        for (int j = 0; j < N; j++) begin
          if (h_time_a[j] != 16'd0) begin
            k = i + j;
            sign = 1;
            if (k >= N) begin
              k = k - N;
              sign = -1;
            end
            term = sign * s2v * int'(h_time_a[j]);
            acc = prod_a[k] + term;
            acc = acc % Q;
            if (acc < 0) begin
              acc = acc + Q;
            end
            prod_a[k] = acc[15:0];
          end
        end
      end
    end
  endtask : tb_schoolbook

  function automatic int tb_rand();
    lfsr_q = lfsr_q * 32'd1664525 + 32'd1013904223;
    return int'(lfsr_q % 32'd12289) - 6144;
  endfunction : tb_rand

  function automatic int tb_rand_bounded(input int span);
    lfsr_q = lfsr_q * 32'd1664525 + 32'd1013904223;
    return int'(lfsr_q % (2 * span + 1)) - span;
  endfunction : tb_rand_bounded

  task automatic tb_expected_norm();
    longint acc;
    longint val;
    acc = 0;
    for (int i = 0; i < N; i++) begin
      val = $signed(exp_s1_a[i]);
      acc = acc + val * val;
      val = $signed(s2_time_a[i]);
      acc = acc + val * val;
    end
    exp_norm_q = acc[39:0];
    exp_accept_q = (acc <= BETA_SQ);
  endtask : tb_expected_norm

  // ---------------------------------------------------------------------------
  // 5. Case setup - all numeric expectations are built before the reset
  // ---------------------------------------------------------------------------
  task automatic tb_setup(input int which, input int seed);
    int val;

    for (int i = 0; i < N; i++) begin
      u_time_a[i]  = 16'd0;
      h_time_a[i]  = 16'd0;
      s2_time_a[i] = 16'd0;
      exp_s1_a[i]  = 16'd0;
    end

    case (which)
      1: begin
        // T1: all-zero identity.
      end
      2: begin
        // T2: s2[0]*h[511] must contribute -1 to coefficient 511.
        h_time_a[511] = 16'd1;
        s2_time_a[0]  = 16'd1;
        exp_s1_a[0]   = 16'd5;
        exp_s1_a[10]  = 16'hfff9;
        exp_s1_a[511] = 16'd3;
      end
      3, 4: begin
        // T3/T4: 2483^2 + 2406^2 + 4699^2 = beta^2; T4 adds 9399.
        h_time_a[0]   = 16'd1;
        exp_s1_a[0]   = 16'd2483;
        exp_s1_a[1]   = 16'd2406;
        exp_s1_a[2]   = (which == 3) ? 16'd4699 : 16'd4700;
      end
      7: begin
        // T7: accept with non-zero s2, non-zero h and a chosen s1.
        h_time_a[0]   = 16'd1;
        h_time_a[1]   = 16'd2;
        h_time_a[511] = 16'd3;
        s2_time_a[0]  = 16'd11;
        s2_time_a[1]  = 16'hfff9;  // -7
        s2_time_a[511]= 16'd5;
        exp_s1_a[0]   = 16'd17;
        exp_s1_a[1]   = 16'hfff0;  // -16
        exp_s1_a[2]   = 16'd23;
        exp_s1_a[511] = 16'd9;
      end
      8: begin
        // T8: dense low-amplitude vectors; the norm stays well inside beta^2.
        lfsr_q = seed[31:0] ^ 32'h5a5a5a5a;
        for (int i = 0; i < N; i++) begin
          val = tb_rand_bounded(3);
          h_time_a[i]  = f_to_mod(val[15:0]);
          val = tb_rand_bounded(5);
          s2_time_a[i] = val[15:0];
          val = tb_rand_bounded(5);
          exp_s1_a[i]  = val[15:0];
        end
      end
      9: begin
        // T9: dense accept 663 below beta^2: 511*257^2 + 532^2.
        for (int i = 0; i < N; i++) begin
          exp_s1_a[i] = 16'd257;
        end
        exp_s1_a[0] = 16'd532;
      end
      10: begin
        // T10: dense reject 402 above beta^2: 511*257^2 + 533^2.
        for (int i = 0; i < N; i++) begin
          exp_s1_a[i] = 16'd257;
        end
        exp_s1_a[0] = 16'd533;
      end
      default: begin
        // T5/T11: dense seeded vectors within the signed balanced range.
        lfsr_q = seed[31:0];
        for (int i = 0; i < N; i++) begin
          val = tb_rand();
          h_time_a[i]  = f_to_mod(val[15:0]);
          val = tb_rand();
          s2_time_a[i] = val[15:0];
          val = tb_rand();
          exp_s1_a[i]  = val[15:0];
        end
      end
    endcase

    tb_schoolbook();

    for (int i = 0; i < N; i++) begin
      u_time_a[i] = f_mod_add(f_to_mod(exp_s1_a[i]), prod_a[i]);
    end

    tb_copy_to_work(1);
    tb_ntt_fwd();
    tb_copy_from_work(1);

    tb_copy_to_work(0);
    tb_ntt_fwd();
    tb_copy_from_work(0);

    tb_expected_norm();
  endtask : tb_setup

  // ---------------------------------------------------------------------------
  // 6. Protocol drivers
  // ---------------------------------------------------------------------------
  task automatic tb_reset();
    rst_n = 1'b0;
    u_tvalid = 1'b0;
    h_tvalid = 1'b0;
    s2_tvalid = 1'b0;
    m_tready <= 1'b1;
    repeat (4) @(posedge clk);
    rst_n = 1'b1;
    repeat (2) @(posedge clk);
  endtask : tb_reset

  task automatic tb_send(input int sel, input int gap = 0);
    for (int i = 0; i < N; i++) begin
      if (gap && ((i % 4) == 0)) begin
        repeat (2) @(posedge clk);
      end
      case (sel)
        0: begin
          u_tvalid = 1'b1;
          u_tdata  = u_ntt_a[i];
        end
        1: begin
          h_tvalid = 1'b1;
          h_tdata  = h_ntt_a[i];
        end
        default: begin
          s2_tvalid = 1'b1;
          s2_tdata  = s2_time_a[i];
        end
      endcase
      do begin
        @(posedge clk);
      end while (!((sel == 0 && u_tready)
                   || (sel == 1 && h_tready)
                   || (sel == 2 && s2_tready)));
      case (sel)
        0: u_tvalid = 1'b0;
        1: h_tvalid = 1'b0;
        default: begin
          s2_tvalid = 1'b0;
          if (i == (N-1)) begin
            last_input_cycle_q = cycle_q;
          end
        end
      endcase
    end
  endtask : tb_send

  task automatic tb_collect(input int bp_mode);
    int idx;
    int watchdog;
    logic last_seen;
    logic finished;
    logic hold_seen;
    logic [15:0] hold_data;
    logic hold_last;

    idx = 0;
    watchdog = 0;
    last_seen = 1'b0;
    finished = 1'b0;
    hold_seen = 1'b0;
    hold_data = 16'd0;
    hold_last = 1'b0;
    m_tready <= 1'b1;

    while ((watchdog < 20000) && !finished) begin
      // While ready is low the DUT must hold data and last stable.
      if (m_tvalid && !m_tready) begin
        if (hold_seen
            && ((m_tdata !== hold_data) || (m_tlast !== hold_last))) begin
          mismatch++;
        end
        hold_seen = 1'b1;
        hold_data = m_tdata;
        hold_last = m_tlast;
      end else begin
        hold_seen = 1'b0;
      end

      case (bp_mode)
        0: m_tready <= 1'b1;
        1: begin
          if ((idx < 4) || (idx == 250) || (idx == 251)) begin
            m_tready <= watchdog[0];
          end else begin
            m_tready <= 1'b1;
          end
        end
        2: begin
          if ((idx >= 100) && (idx < 106)) begin
            m_tready <= watchdog[0];
          end else begin
            m_tready <= 1'b1;
          end
        end
        3: begin
          m_tready <= (((watchdog + idx) % 3) != 0);
        end
        4: begin
          if ((idx % 17) == 0) begin
            m_tready <= watchdog[0];
          end else begin
            m_tready <= 1'b1;
          end
        end
        default: m_tready <= 1'b1;
      endcase

      @(posedge clk);
      watchdog++;

      if (hs_d1 === 1'b1) begin
        if (idx >= N) begin
          mismatch++;
        end else begin
          if (data_d1 !== exp_s1_a[idx]) begin
            mismatch++;
          end
          if (last_d1 !== (idx == (N-1))) begin
            mismatch++;
          end
          if (last_d1 === 1'b1) begin
            last_seen = 1'b1;
          end
          idx++;
        end
      end

      if (ver_d1 === 1'b1) begin
        if (!last_seen) begin
          mismatch++;
        end
        if (verify_accept !== exp_accept_q) begin
          mismatch++;
        end
        if (verify_norm_sq !== exp_norm_q) begin
          mismatch++;
        end
        verdict_cycle_q = cycle_q;
        last_latency_q = verdict_cycle_q - last_input_cycle_q;
        m_tready <= 1'b0;
        finished = 1'b1;
      end
    end
    if (!finished) begin
      mismatch++;
    end
  endtask : tb_collect

  // ---------------------------------------------------------------------------
  // 7. Runs and result token
  // ---------------------------------------------------------------------------
  initial begin
    int run;
    int bp_c;
    int gap_c;
    int seed_c;
    int total_runs_c;

    if (!$value$plusargs("SEED=%d", seed_base_q)) seed_base_q = 0;
    if (!$value$plusargs("SEED_COUNT=%d", seed_count_q)) seed_count_q = 1;
    if (!$value$plusargs("BP=%d", bp_mode_q)) bp_mode_q = 0;
    if (!$value$plusargs("REGRESS=%d", regress_q)) regress_q = 0;
    if (seed_count_q < 1) seed_count_q = 1;

    total_runs_c = 8;
    if (regress_q != 0) begin
      total_runs_c = 16 + seed_count_q;
    end

    for (run = 1; run <= total_runs_c; run++) begin
      bp_c = 0;
      gap_c = 0;
      seed_c = seed_base_q + run * 7919;
      case (run)
        1: case_id = 1;
        2: case_id = 2;
        3: case_id = 3;
        4: case_id = 4;
        5, 6, 7: case_id = 5;
        8: begin
          case_id = 3;  // T6 is a backpressure replay of the T3 vector
          bp_c = 1;
        end
        9: case_id = 7;
        10: case_id = 8;
        11: case_id = 9;
        12: case_id = 10;
        13: begin case_id = 5; bp_c = 1; end
        14: begin case_id = 5; bp_c = 2; end
        15: begin case_id = 5; bp_c = 3; end
        16: begin case_id = 7; bp_c = 4; gap_c = 1; end
        default: begin
          case_id = 5;
          bp_c = bp_mode_q;
          seed_c = seed_base_q + (run - 8) * 104729;
        end
      endcase

      tb_setup(case_id, seed_c);
      tb_reset();
      cycles = 0;
      last_input_cycle_q = 0;
      last_latency_q = 0;
      tb_send(0, gap_c);
      tb_send(1, gap_c);
      tb_send(2, gap_c);
      tb_collect(bp_c);

      if ((bp_c == 0) && (gap_c == 0)
          && (last_latency_q != 12296)) begin
        mismatch++;
      end
      if ((bp_c != 0) && (last_latency_q < 12296)) begin
        mismatch++;
      end

      $display("RUN %0d  CASE T%0d  seed=%0d  bp=%0d  gap=%0d  latency=%0d  norm=%0d  accept=%0d  mismatches=%0d",
               run, case_id, seed_c, bp_c, gap_c, last_latency_q,
               exp_norm_q, exp_accept_q, mismatch);
    end

    if (mismatch == 0) begin
      $display("RESULT  = PASS");
    end else begin
      $display("RESULT  = FAIL   (%0d mismatch(es))", mismatch);
    end
    $finish;
  end

endmodule : tb_falcon512_verify

`default_nettype wire
