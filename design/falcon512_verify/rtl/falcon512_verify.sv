///////////////////////////////////////////////////////
// Module : falcon512_verify
// Author   : desktop-ifrf24e\najam
// Description: Falcon-512 signature verification datapath. The block accepts
//              the hash target u and public key h in NTT form, and s2 in
//              coefficient form, then reconstructs s1 = u - s2*h over
//              Z_q[x]/(x^512+1) and accepts when the squared norm of
//              (s1,s2) is at most 34034726. Three coefficient streams are
//              accepted in parallel; the transform engine is then reused for
//              a forward NTT and an inverse NTT, so one verification costs
//              12,296 cycles from the last input beat to the verdict.
///////////////////////////////////////////////////////
`default_nettype none

module falcon512_verify (
  input  logic                 axi_st_clk        ,
  input  logic                 axi_st_areset_n   ,

  input  logic                 u_tvalid          ,
  output logic                 u_tready          ,
  input  logic [15:0]          u_tdata           ,

  input  logic                 h_tvalid          ,
  output logic                 h_tready          ,
  input  logic [15:0]          h_tdata           ,

  input  logic                 s2_tvalid         ,
  output logic                 s2_tready         ,
  input  logic [15:0]          s2_tdata          ,

  output logic                 m_tvalid          ,
  input  logic                 m_tready          ,
  output logic [15:0]          m_tdata           ,
  output logic                 m_tlast           ,

  output logic                 verify_valid      ,
  output logic                 verify_accept     ,
  output logic [39:0]          verify_norm_sq
);
  // Yosys does not accept an import statement inside a module, so the package
  // constants are aliased locally and the helpers are called with a qualifier.
  localparam int         N        = falcon512_pkg::N;
  localparam int         Q        = falcon512_pkg::Q;
  localparam int         BETA_SQ  = falcon512_pkg::BETA_SQ;
  localparam logic [15:0] PSI      = falcon512_pkg::PSI;
  localparam logic [15:0] PSI_INV  = falcon512_pkg::PSI_INV;
  localparam logic [15:0] N_INV    = falcon512_pkg::N_INV;

  // ---------------------------------------------------------------------------
  // 1. Local parameters and state encoding
  // ---------------------------------------------------------------------------
  localparam logic [9:0]  N_Q       = 10'd512;
  localparam logic [39:0] BETA_SQ_Q = BETA_SQ;

  localparam logic [3:0] ST_LOAD          = 4'd0;
  localparam logic [3:0] ST_FWD_START     = 4'd1;
  localparam logic [3:0] ST_FWD_WAIT      = 4'd2;
  localparam logic [3:0] ST_POINT_ISSUE   = 4'd3;
  localparam logic [3:0] ST_POINT_COMMIT  = 4'd4;
  localparam logic [3:0] ST_INV_START     = 4'd5;
  localparam logic [3:0] ST_INV_WAIT      = 4'd6;
  localparam logic [3:0] ST_RESULT_ISSUE  = 4'd7;
  localparam logic [3:0] ST_RESULT_COMMIT = 4'd8;
  localparam logic [3:0] ST_DONE          = 4'd9;
  localparam logic [3:0] ST_PERMUTE       = 4'd10;

  // ---------------------------------------------------------------------------
  // 2. Coefficient storage and stream state
  // ---------------------------------------------------------------------------
  logic [15:0] u_ram     [0:N-1];
  logic [15:0] h_ram     [0:N-1];
  logic [15:0] s1hat_ram [0:N-1];

  logic [3:0]   state_q;
  logic [9:0]   u_cnt_q;
  logic [9:0]   h_cnt_q;
  logic [9:0]   s2_cnt_q;
  logic         u_tready_q;
  logic         h_tready_q;
  logic         s2_tready_q;
  logic [15:0]  twist_q;

  logic [39:0]  norm_q;
  logic         verify_valid_q;
  logic         verify_accept_q;
  logic [39:0]  verify_norm_sq_q;

  // ---------------------------------------------------------------------------
  // 3. Transform engine interface
  // ---------------------------------------------------------------------------
  logic         ntt_start_q;
  logic         ntt_inv_q;
  logic         ntt_busy;
  logic         ntt_done;
  logic         ntt_load_we_q;
  logic [8:0]   ntt_load_addr_q;
  logic [15:0]  ntt_load_data_q;
  logic         ntt_rd_en_q;
  logic [8:0]   ntt_rd_addr_q;
  logic [15:0]  ntt_rd_data;

  logic [8:0]   point_i_q;
  logic [8:0]   point_addr_q;
  logic [8:0]   perm_i_q;
  logic         u_rd_en_q;
  logic         h_rd_en_q;
  logic [8:0]   u_rd_addr_q;
  logic [8:0]   h_rd_addr_q;
  logic [15:0]  u_rd_data;
  logic [15:0]  h_rd_data;

  // ---------------------------------------------------------------------------
  // 4. Result stream state
  // ---------------------------------------------------------------------------
  logic [8:0]   result_i_q;
  logic [8:0]   result_addr_q;
  logic [15:0]  result_data_q;
  logic         result_last_q;
  logic         result_valid_q;
  logic [15:0]  untwist_q;
  integer       s2_val; // used only by the RTL_SIM range check

  assign u_tready = u_tready_q;
  assign h_tready = h_tready_q;
  assign s2_tready = s2_tready_q;

  assign u_rd_data = u_ram[u_rd_addr_q];
  assign h_rd_data = h_ram[h_rd_addr_q];

  assign m_tvalid = result_valid_q;
  assign m_tdata  = result_data_q;
  assign m_tlast  = result_valid_q && result_last_q;

  assign verify_valid    = verify_valid_q;
  assign verify_accept   = verify_accept_q;
  assign verify_norm_sq  = verify_norm_sq_q;

  falcon512_ntt u_ntt (
    .axi_st_clk      (axi_st_clk       ),
    .axi_st_areset_n (axi_st_areset_n  ),
    .start           (ntt_start_q      ),
    .inv             (ntt_inv_q        ),
    .load_we         (ntt_load_we_q    ),
    .load_addr       (ntt_load_addr_q  ),
    .load_data       (ntt_load_data_q  ),
    .rd_en           (ntt_rd_en_q      ),
    .rd_addr         (ntt_rd_addr_q    ),
    .rd_data         (ntt_rd_data      ),
    .busy            (ntt_busy         ),
    .done            (ntt_done         )
  );

  // ---------------------------------------------------------------------------
  // 5. Main controller
  // ---------------------------------------------------------------------------
  always_ff @(posedge axi_st_clk or negedge axi_st_areset_n) begin
    if (!axi_st_areset_n) begin
      state_q          <= ST_LOAD;
      u_cnt_q          <= 10'd0;
      h_cnt_q          <= 10'd0;
      s2_cnt_q         <= 10'd0;
      u_tready_q       <= 1'b0;
      h_tready_q       <= 1'b0;
      s2_tready_q      <= 1'b0;
      twist_q          <= 16'd1;
      norm_q           <= 40'd0;
      verify_valid_q   <= 1'b0;
      verify_accept_q  <= 1'b0;
      verify_norm_sq_q <= 40'd0;
      ntt_start_q      <= 1'b0;
      ntt_inv_q        <= 1'b0;
      ntt_load_we_q    <= 1'b0;
      ntt_load_addr_q  <= 9'd0;
      ntt_load_data_q  <= 16'd0;
      ntt_rd_en_q      <= 1'b0;
      ntt_rd_addr_q    <= 9'd0;
      point_i_q        <= 9'd0;
      point_addr_q     <= 9'd0;
      perm_i_q         <= 9'd0;
      u_rd_en_q        <= 1'b0;
      h_rd_en_q        <= 1'b0;
      u_rd_addr_q      <= 9'd0;
      h_rd_addr_q      <= 9'd0;
      result_i_q       <= 9'd0;
      result_addr_q    <= 9'd0;
      result_data_q    <= 16'd0;
      result_last_q    <= 1'b0;
      result_valid_q   <= 1'b0;
      untwist_q        <= 16'd1;
    end else begin
      // One-cycle pulses default to zero; each state re-asserts what it needs.
      ntt_start_q   <= 1'b0;
      ntt_load_we_q <= 1'b0;
      ntt_rd_en_q   <= 1'b0;
      u_rd_en_q     <= 1'b0;
      h_rd_en_q     <= 1'b0;
      verify_valid_q <= 1'b0;

      // Ready depends only on state and counters, never on tvalid.
      u_tready_q  <= (state_q == ST_LOAD) && (u_cnt_q  < N_Q);
      h_tready_q  <= (state_q == ST_LOAD) && (h_cnt_q  < N_Q);
      s2_tready_q <= (state_q == ST_LOAD) && (s2_cnt_q < N_Q);

      if ((state_q == ST_LOAD) && u_tvalid && u_tready_q) begin
        u_ram[u_cnt_q[8:0]] <= u_tdata;
        u_cnt_q <= u_cnt_q + 10'd1;
      end
      if ((state_q == ST_LOAD) && h_tvalid && h_tready_q) begin
        h_ram[h_cnt_q[8:0]] <= h_tdata;
        h_cnt_q <= h_cnt_q + 10'd1;
      end
      if ((state_q == ST_LOAD) && s2_tvalid && s2_tready_q) begin
        ntt_load_we_q   <= 1'b1;
        ntt_load_addr_q <= falcon512_pkg::f_bitrev(s2_cnt_q[8:0]);
        ntt_load_data_q <= falcon512_pkg::f_mod_mul(falcon512_pkg::f_to_mod(s2_tdata), twist_q);
        twist_q         <= falcon512_pkg::f_mod_mul(twist_q, PSI);
        norm_q          <= norm_q + falcon512_pkg::f_square(s2_tdata);
        s2_cnt_q        <= s2_cnt_q + 10'd1;
      end

      case (state_q)
        ST_LOAD: begin
          if ((u_cnt_q == N_Q) && (h_cnt_q == N_Q)
              && (s2_cnt_q == N_Q)) begin
            state_q <= ST_FWD_START;
          end
        end

        ST_FWD_START: begin
          ntt_start_q <= 1'b1;
          ntt_inv_q   <= 1'b0;
          state_q     <= ST_FWD_WAIT;
        end

        ST_FWD_WAIT: begin
          if (ntt_done) begin
            point_i_q <= 9'd0;
            state_q   <= ST_POINT_ISSUE;
          end
        end

        ST_POINT_ISSUE: begin
          ntt_rd_en_q   <= 1'b1;
          ntt_rd_addr_q <= point_i_q;
          u_rd_en_q     <= 1'b1;
          h_rd_en_q     <= 1'b1;
          u_rd_addr_q   <= point_i_q;
          h_rd_addr_q   <= point_i_q;
          point_addr_q  <= point_i_q;
          state_q       <= ST_POINT_COMMIT;
        end

        ST_POINT_COMMIT: begin
          // Keep the pointwise result away from the NTT work memory: a later
          // butterfly read can still need a value that an early permuted write
          // would otherwise overwrite. It is copied back after the last read.
          s1hat_ram[falcon512_pkg::f_bitrev(point_addr_q)] <= falcon512_pkg::f_mod_sub(u_rd_data,
                                               falcon512_pkg::f_mod_mul(ntt_rd_data, h_rd_data));
          if (point_i_q == (N_Q - 10'd1)) begin
            perm_i_q <= 9'd0;
            state_q  <= ST_PERMUTE;
          end else begin
            point_i_q <= point_i_q + 9'd1;
            state_q   <= ST_POINT_ISSUE;
          end
        end

        ST_PERMUTE: begin
          ntt_load_we_q   <= 1'b1;
          ntt_load_addr_q <= perm_i_q;
          ntt_load_data_q <= s1hat_ram[perm_i_q];
          if (perm_i_q == 9'd511) begin
            state_q <= ST_INV_START;
          end else begin
            perm_i_q <= perm_i_q + 9'd1;
          end
        end

        ST_INV_START: begin
          ntt_start_q <= 1'b1;
          ntt_inv_q   <= 1'b1;
          state_q     <= ST_INV_WAIT;
        end

        ST_INV_WAIT: begin
          if (ntt_done) begin
            result_i_q <= 9'd0;
            untwist_q  <= 16'd1;
            state_q    <= ST_RESULT_ISSUE;
          end
        end

        ST_RESULT_ISSUE: begin
          if (result_valid_q) begin
            if (m_tready) begin
              result_valid_q  <= 1'b0;
              if (result_last_q) begin
                verify_valid_q   <= 1'b1;
                verify_accept_q  <= (norm_q <= BETA_SQ_Q);
                verify_norm_sq_q <= norm_q;
                state_q          <= ST_DONE;
              end
            end
          end else begin
            ntt_rd_en_q   <= 1'b1;
            ntt_rd_addr_q <= result_i_q;
            result_addr_q <= result_i_q;
            state_q       <= ST_RESULT_COMMIT;
          end
        end

        ST_RESULT_COMMIT: begin
          result_data_q <= falcon512_pkg::f_balance(falcon512_pkg::f_mod_mul(
                            falcon512_pkg::f_mod_mul(ntt_rd_data, N_INV), untwist_q));
          result_last_q <= (result_i_q == (N_Q - 10'd1));
          result_valid_q <= 1'b1;
          untwist_q     <= falcon512_pkg::f_mod_mul(untwist_q, PSI_INV);
          norm_q        <= norm_q + falcon512_pkg::f_square(falcon512_pkg::f_balance(falcon512_pkg::f_mod_mul(
                            falcon512_pkg::f_mod_mul(ntt_rd_data, N_INV), untwist_q)));
          result_i_q    <= result_i_q + 9'd1;
          state_q       <= ST_RESULT_ISSUE;
        end

        ST_DONE: begin
          // Verdict and result stay stable until reset; extra input beats are
          // ignored because all three ready outputs are low here.
          state_q <= ST_DONE;
        end

        default: begin
          state_q <= ST_LOAD;
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // 6. Elaboration checks - unguarded, before simulation-only code
  // ---------------------------------------------------------------------------
  generate
    if (N != 512 || Q != 12289 || BETA_SQ != 34034726
        || PSI != 16'd10302 || PSI_INV != 16'd8974) begin : g_falcon512_config
      initial begin
        $fatal(1, "falcon512_verify: only published Falcon-512 constants are supported");
      end
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 7. Simulation-only range, protocol and overflow checks
  // ---------------------------------------------------------------------------
`ifdef RTL_SIM
  always_ff @(posedge axi_st_clk or negedge axi_st_areset_n) begin
    if (!axi_st_areset_n) begin
      // Diagnostics are qualified by handshake and state in the next block.
    end else begin
      if ((state_q == ST_LOAD) && u_tvalid && u_tready_q
          && (u_tdata >= Q)) begin
        $error("falcon512_verify: u coefficient is outside [0,Q-1]");
      end
      if ((state_q == ST_LOAD) && h_tvalid && h_tready_q
          && (h_tdata >= Q)) begin
        $error("falcon512_verify: h coefficient is outside [0,Q-1]");
      end
      if ((state_q == ST_LOAD) && s2_tvalid && s2_tready_q) begin
        s2_val = $signed(s2_tdata);
        if ((s2_val < -6144) || (s2_val > 6144)) begin
          $error("falcon512_verify: s2 coefficient is outside the balanced range");
        end
      end
      if ((state_q != ST_LOAD) && ((u_cnt_q != N_Q) || (h_cnt_q != N_Q)
          || (s2_cnt_q != N_Q))) begin
        $error("falcon512_verify: left load state before all streams completed");
      end
      if (result_valid_q && m_tvalid && m_tlast && m_tready
          && (norm_q > BETA_SQ_Q) && verify_accept_q) begin
        $error("falcon512_verify: accepted a norm above the bound");
      end
    end
  end
`endif

endmodule : falcon512_verify

`default_nettype wire
