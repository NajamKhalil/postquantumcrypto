///////////////////////////////////////////////////////
// Module : falcon512_pkg
// Author   : desktop-ifrf24e\najam
// Description: Shared Falcon-512 constants and modular arithmetic helpers.
//              The prime is fixed at 12289, the ring degree at 512 and the
//              negacyclic twist root at 10302, so every helper is exact for
//              this parameter set. Multiplication uses a Barrett constant
//              rather than a divider: one wide constant product and at most
//              two corrective subtractions keep the butterfly short.
//              Function results use the classic name assignment form so both
//              Icarus and Yosys accept the same source without a define.
///////////////////////////////////////////////////////
`default_nettype none

package falcon512_pkg;
  // ---------------------------------------------------------------------------
  // 1. Constants for the published Falcon-512 parameter set
  // ---------------------------------------------------------------------------
  localparam int         N          = 512;
  localparam int         Q          = 12289;
  localparam int         Q_HALF     = 6144;
  localparam int         LOG2_N     = 9;
  localparam int         BETA_SQ    = 34034726;
  localparam int         BARRETT_M  = 21843; // floor(2^28 / Q)

  localparam logic [15:0] PSI        = 16'd10302; // primitive 1024th root
  localparam logic [15:0] PSI_INV    = 16'd8974;  // inverse of PSI mod Q
  localparam logic [15:0] OMEGA      = 16'd3400;  // PSI^2, primitive 512th root
  localparam logic [15:0] N_INV      = 16'd12265; // inverse of 512 mod Q

  // ---------------------------------------------------------------------------
  // 2. Modular helpers
  // ---------------------------------------------------------------------------
  function automatic logic [15:0] f_mod_add(input logic [15:0] a,
                                             input logic [15:0] b);
    logic [16:0] sum;
    sum = {1'b0, a} + {1'b0, b};
    if (sum >= Q) begin
      sum = sum - Q;
    end
    f_mod_add = sum;
  endfunction

  function automatic logic [15:0] f_mod_sub(input logic [15:0] a,
                                             input logic [15:0] b);
    logic [16:0] diff;
    if (a >= b) begin
      diff = {1'b0, a} - {1'b0, b};
    end else begin
      diff = {1'b0, a} + Q - {1'b0, b};
    end
    f_mod_sub = diff;
  endfunction

  function automatic logic [15:0] f_mod_mul(input logic [15:0] a,
                                             input logic [15:0] b);
    logic [31:0]  prod;
    logic [45:0]  mm;
    logic [45:0]  z;
    logic [45:0]  t;
    logic [15:0]  q16;
    logic signed [45:0] r;

    prod = a * b;
    mm   = BARRETT_M;
    z    = {14'd0, prod} * mm;
    t    = z >> 28;
    q16  = Q;

    // Barrett leaves a signed residue in (-Q, 2Q). One addition and at most
    // two subtractions make the result canonical without a divider.
    r = $signed({18'd0, prod}) - $signed(t * q16);
    if (r < 0) begin
      r = r + Q;
    end
    if (r >= Q) begin
      r = r - Q;
    end
    if (r >= Q) begin
      r = r - Q;
    end
    f_mod_mul = r[15:0];
  endfunction

  function automatic logic [15:0] f_to_mod(input logic [15:0] val);
    logic signed [31:0] tmp;
    tmp = $signed(val);
    if (tmp < 0) begin
      tmp = tmp + Q;
    end
    f_to_mod = tmp;
  endfunction

  function automatic logic [15:0] f_balance(input logic [15:0] val);
    logic signed [31:0] tmp;
    tmp = $signed({1'b0, val});
    if (tmp > Q_HALF) begin
      tmp = tmp - Q;
    end
    f_balance = tmp;
  endfunction

  function automatic logic signed [39:0] f_square(input logic [15:0] balanced);
    logic signed [39:0] val;
    val = $signed(balanced);
    f_square = val * val;
  endfunction

  // ---------------------------------------------------------------------------
  // 3. Stage roots and bit reversal
  // ---------------------------------------------------------------------------
  function automatic logic [15:0] f_stage_root_fwd(input int stage);
    f_stage_root_fwd = 16'd0;
    case (stage)
      1: f_stage_root_fwd = 16'd12288;
      2: f_stage_root_fwd = 16'd1479;
      3: f_stage_root_fwd = 16'd8246;
      4: f_stage_root_fwd = 16'd4134;
      5: f_stage_root_fwd = 16'd5860;
      6: f_stage_root_fwd = 16'd7311;
      7: f_stage_root_fwd = 16'd12149;
      8: f_stage_root_fwd = 16'd8340;
      9: f_stage_root_fwd = 16'd3400;
      default: f_stage_root_fwd = 16'd0;
    endcase
  endfunction

  function automatic logic [15:0] f_stage_root_inv(input int stage);
    f_stage_root_inv = 16'd0;
    case (stage)
      1: f_stage_root_inv = 16'd12288;
      2: f_stage_root_inv = 16'd10810;
      3: f_stage_root_inv = 16'd7143;
      4: f_stage_root_inv = 16'd10984;
      5: f_stage_root_inv = 16'd8747;
      6: f_stage_root_inv = 16'd9650;
      7: f_stage_root_inv = 16'd790;
      8: f_stage_root_inv = 16'd1696;
      9: f_stage_root_inv = 16'd2859;
      default: f_stage_root_inv = 16'd0;
    endcase
  endfunction

  function automatic logic [8:0] f_bitrev(input logic [8:0] idx);
    logic [8:0] rev;
    for (int i = 0; i < LOG2_N; i++) begin
      rev[i] = idx[LOG2_N - 1 - i];
    end
    f_bitrev = rev;
  endfunction

endpackage

`default_nettype wire
