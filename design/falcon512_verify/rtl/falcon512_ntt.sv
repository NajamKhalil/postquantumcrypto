///////////////////////////////////////////////////////
// Module : falcon512_ntt
// Author   : desktop-ifrf24e\najam
// Description: In-place radix-2 Cooley-Tukey transform for the Falcon-512 ring.
//              One butterfly engine is reused for all nine stages: each stage
//              has 256 butterflies and the controller uses two clocks per
//              butterfly, so a transform takes 4608 cycles plus control. The
//              coefficient memory is written bit-reversed
//              by the caller for a forward transform and read bit-reversed by
//              the caller after an inverse transform; this makes the engine
//              itself free of a separate permutation pass.
///////////////////////////////////////////////////////
`default_nettype none

module falcon512_ntt (
  input  logic                 axi_st_clk      ,
  input  logic                 axi_st_areset_n ,
  input  logic                 start           ,
  input  logic                 inv             ,
  input  logic                 load_we         ,
  input  logic [8:0]           load_addr       ,
  input  logic [15:0]          load_data       ,
  input  logic                 rd_en           ,
  input  logic [8:0]           rd_addr         ,
  output logic [15:0]          rd_data         ,
  output logic                 busy            ,
  output logic                 done
);
  // Yosys does not accept an import statement inside a module, so the package
  // constants are aliased locally and the helpers are called with a qualifier.
  localparam int         N      = falcon512_pkg::N;
  localparam int         Q      = falcon512_pkg::Q;
  localparam int         LOG2_N = falcon512_pkg::LOG2_N;
  localparam logic [15:0] OMEGA = falcon512_pkg::OMEGA;

  // ---------------------------------------------------------------------------
  // 1. Local parameters and state encoding
  // ---------------------------------------------------------------------------
  localparam int BFLY_TOTAL = (N * LOG2_N) / 2;
  localparam int LAST_BFLY  = BFLY_TOTAL - 1;

  localparam logic [1:0] ST_IDLE   = 2'd0;
  localparam logic [1:0] ST_FETCH  = 2'd1;
  localparam logic [1:0] ST_STORE  = 2'd2;
  localparam logic [1:0] ST_FINISH = 2'd3;

  // ---------------------------------------------------------------------------
  // 2. Storage and control state
  // ---------------------------------------------------------------------------
  logic [15:0] mem [0:N-1];

  logic [1:0]   state_q;
  logic         inv_q;
  logic         done_q;
  logic [3:0]   stage_q;
  logic [8:0]   grp_q;
  logic [8:0]   k_q;
  logic [11:0]  bfly_count_q;
  logic [15:0]  w_q;

  logic [8:0]   addr_a_q;
  logic [8:0]   addr_b_q;
  logic [15:0]  rd_a_q;
  logic [15:0]  rd_b_q;

  // ---------------------------------------------------------------------------
  // 3. Combinational butterfly and address generation
  // ---------------------------------------------------------------------------
  logic [8:0]   half_c;
  logic [8:0]   groups_c;
  logic [8:0]   addr_a_c;
  logic [8:0]   addr_b_c;
  logic [15:0]  root_c;
  logic [15:0]  prod_c;
  logic [15:0]  sum_c;
  logic [15:0]  diff_c;
  logic [15:0]  w_next_c;
  int            idx0_int;

  always_comb begin
    half_c    = 9'd0;
    groups_c  = 9'd0;
    addr_a_c  = 9'd0;
    addr_b_c  = 9'd0;
    root_c    = 16'd0;
    w_next_c  = 16'd1;
    idx0_int  = 0;

    if ((stage_q >= 4'd1) && (stage_q <= 4'd9)) begin
      half_c   = 9'd1 << (stage_q - 4'd1);
      groups_c = N >> stage_q;
      idx0_int = int'(grp_q) * 2 * int'(half_c) + int'(k_q);
      addr_a_c = idx0_int;
      addr_b_c = idx0_int + int'(half_c);
      root_c   = inv_q ? falcon512_pkg::f_stage_root_inv(int'(stage_q))
                       : falcon512_pkg::f_stage_root_fwd(int'(stage_q));
    end

    // The twiddle is held for the whole group and reset at its last butterfly.
    if ((half_c != 9'd0) && ((k_q + 9'd1) >= half_c)) begin
      w_next_c = 16'd1;
    end else begin
      w_next_c = falcon512_pkg::f_mod_mul(w_q, root_c);
    end

    prod_c = falcon512_pkg::f_mod_mul(rd_b_q, w_q);
    sum_c  = falcon512_pkg::f_mod_add(rd_a_q, prod_c);
    diff_c = falcon512_pkg::f_mod_sub(rd_a_q, prod_c);
  end

  assign busy = (state_q == ST_FETCH) || (state_q == ST_STORE)
                || (state_q == ST_FINISH);
  assign done = done_q;
  assign rd_data = mem[rd_addr];

  // ---------------------------------------------------------------------------
  // 4. Memory ports and transform controller
  // ---------------------------------------------------------------------------
  always_ff @(posedge axi_st_clk or negedge axi_st_areset_n) begin
    if (!axi_st_areset_n) begin
      state_q      <= ST_IDLE;
      inv_q        <= 1'b0;
      done_q       <= 1'b0;
      stage_q      <= 4'd0;
      grp_q        <= 9'd0;
      k_q          <= 9'd0;
      bfly_count_q <= 12'd0;
      w_q          <= 16'd1;
      addr_a_q     <= 9'd0;
      addr_b_q     <= 9'd0;
      rd_a_q       <= 16'd0;
      rd_b_q       <= 16'd0;
    end else begin
      done_q <= 1'b0;

      // The caller owns the memory while the engine is idle. A store in the
      // butterfly stage wins over an external write in the same cycle, so a
      // stray write cannot corrupt an in-flight transform.
      if (load_we && !busy) begin
        mem[load_addr] <= load_data;
      end
      if (state_q == ST_FETCH) begin
        rd_a_q   <= mem[addr_a_c];
        rd_b_q   <= mem[addr_b_c];
        addr_a_q <= addr_a_c;
        addr_b_q <= addr_b_c;
      end
      if (state_q == ST_STORE) begin
        mem[addr_a_q] <= sum_c;
        mem[addr_b_q] <= diff_c;
      end

      case (state_q)
        ST_IDLE: begin
          if (start) begin
            inv_q        <= inv;
            stage_q      <= 4'd1;
            grp_q        <= 9'd0;
            k_q          <= 9'd0;
            bfly_count_q <= 12'd0;
            w_q          <= 16'd1;
            state_q      <= ST_FETCH;
          end
        end

        ST_FETCH: begin
          state_q <= ST_STORE;
        end

        ST_STORE: begin
          bfly_count_q <= bfly_count_q + 12'd1;
          w_q          <= w_next_c;
          state_q      <= ST_FETCH;

          if (bfly_count_q == LAST_BFLY[11:0]) begin
            done_q  <= 1'b1;
            state_q <= ST_FINISH;
          end else if ((k_q + 9'd1) >= half_c) begin
            k_q <= 9'd0;
            if ((grp_q + 9'd1) >= groups_c) begin
              grp_q <= 9'd0;
              if (stage_q == 4'd9) begin
                done_q  <= 1'b1;
                state_q <= ST_FINISH;
              end else begin
                stage_q <= stage_q + 4'd1;
              end
            end else begin
              grp_q <= grp_q + 9'd1;
            end
          end else begin
            k_q <= k_q + 9'd1;
          end
        end

        ST_FINISH: begin
          state_q <= ST_IDLE;
        end

        default: begin
          state_q <= ST_IDLE;
        end
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // 5. Elaboration checks - unguarded, before simulation-only code
  // ---------------------------------------------------------------------------
  generate
    if (N != 512 || Q != 12289 || LOG2_N != 9 || OMEGA != 16'd3400) begin : g_ntt_config
      initial begin
        $fatal(1, "falcon512_ntt: only N=512, Q=12289 and OMEGA=3400 are supported");
      end
    end
  endgenerate

  // ---------------------------------------------------------------------------
  // 6. Simulation-only protocol checks
  // ---------------------------------------------------------------------------
`ifdef RTL_SIM
  always_ff @(posedge axi_st_clk or negedge axi_st_areset_n) begin
    if (!axi_st_areset_n) begin
      // nothing to clear: diagnostics are qualified by busy in the next block
    end else begin
      if (start && busy) begin
        $error("falcon512_ntt: start asserted while busy");
      end
      if (load_we && busy) begin
        $error("falcon512_ntt: external write while busy");
      end
      if (rd_en && busy) begin
        $error("falcon512_ntt: external read while busy");
      end
    end
  end
`endif

endmodule : falcon512_ntt

`default_nettype wire
