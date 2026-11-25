# Falcon-512 Verify Core - Design Specification

| | |
|---|---|
| Block | `falcon512_verify` (`rtl/falcon512_verify.sv`) |
| Function | verifies a Falcon-512 signature over the NTRU ring with `q=12289`, `n=512`, `beta^2=34034726` |
| Author | desktop-ifrf24e\najam |
| Language | SystemVerilog-2012 |
| Target | FPGA synthesizable RTL, single clock and one active-low asynchronous reset |
| Clocking | `axi_st_clk` / `axi_st_areset_n` |
| Verify latency | 5,632 cycles from the last accepted input beat to the verdict, fixed |
| Throughput | one verification per **6,144 cycles** including input load; this version does not overlap two verifications |
| Modes | accept/reject according to the norm bound; no other modes |

---

## 1. What this is

A signature-verification datapath for the Falcon-512 parameter set described in the supplied design document: it takes the hash target `u` and public key `h` in NTT form, takes the signature component `s2` in coefficient form, reconstructs `s1 = u - s2*h` in the ring `Z_q[x]/(x^512 + 1)`, and accepts only when the squared Euclidean norm of `(s1, s2)` does not exceed `floor(beta^2)`.

The property that matters is that **the polynomial product is the exact negacyclic product modulo 12289**, including the sign flip when an exponent wraps past `x^511 = -1`. A schoolbook implementation would also be exact but needs 262,144 multiplications; the NTT used here needs 4,608 butterflies and is the same integer arithmetic the source document identifies as the reason the scheme is fast.

What it is not: it is not a key generator and not a signer, it does not implement SHAKE256, and it does not decompress the Falcon byte-encoded `s2` or `h`. Those interfaces are outside this block and their outputs are presented here as coefficient streams. Section 6 states the exact boundary.

---

## 2. Interface

### 2.1 Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `Q` | 12289 | fixed | The Falcon prime. `Q-1 = 2^12 * 3`, so a primitive 1024th root exists and a 512-point NTT is exact. |
| `N` | 512 | fixed | Ring dimension and number of coefficients per polynomial. |
| `PSI` | 10302 | `PSI^512 = -1 mod Q` | Primitive 1024th root `11^12 mod 12289`, used for the negacyclic twist. |
| `PSI_INV` | 8974 | `PSI * PSI_INV = 1 mod Q` | Inverse root used when reading the inverse NTT result. |
| `BETA_SQ` | 34034726 | fixed | Acceptance bound from Table 8.2 of the source document. The comparison is inclusive. |
| `DATA_W` | 16 | 14..16 | Width of a coefficient beat. Two spare bits make the signed balanced representation unambiguous. |

There are no elaboration-time configuration checks beyond the fixed-constant assertions: the module is parameterised only so the arithmetic stays readable, and changing a parameter away from the published Falcon-512 values is not supported.

### 2.2 Ports

| Port | Dir | Width | Meaning |
|---|---|---|---|
| `axi_st_clk` | in | 1 | Working clock, rising edge |
| `axi_st_areset_n` | in | 1 | Asynchronous active-low reset for control and state |
| `u_tvalid` / `u_tready` | in / out | 1 | Ready/valid stream of 512 NTT-domain `u` coefficients, natural order |
| `u_tdata` | in | 16 | Unsigned coefficient in `[0, Q-1]` |
| `h_tvalid` / `h_tready` | in / out | 1 | Ready/valid stream of 512 NTT-domain public-key coefficients, natural order |
| `h_tdata` | in | 16 | Unsigned coefficient in `[0, Q-1]` |
| `s2_tvalid` / `s2_tready` | in / out | 1 | Ready/valid stream of 512 `s2` coefficients, natural order |
| `s2_tdata` | in | 16 | Signed balanced coefficient in `[-6144, 6144]` |
| `m_tvalid` / `m_tready` | in / out | 1 | Ready/valid output stream of the 512 reconstructed `s1` coefficients |
| `m_tdata` | out | 16 | Signed balanced coefficient in `[-6144, 6144]` |
| `m_tlast` | out | 1 | High on the final coefficient |
| `verify_valid` | out | 1 | Single-cycle verdict pulse, coincident with `m_tlast && m_tready` |
| `verify_accept` | out | 1 | High when `norm_sq <= BETA_SQ` |
| `verify_norm_sq` | out | 40 | Squared norm of `(s1, s2)`, full precision |

No port was added beyond what the verification equation needs. The `s1` stream is exposed because the norm bound alone cannot distinguish a correct reconstruction from two compensating errors; the testbench checks every coefficient against an independent model. `verify_norm_sq` is exposed for the same reason: a pass/fail bit hides a norm accumulator that is wrong but still on the same side of the bound.

### 2.3 Input and output protocol

Each stream is a standard ready/valid handshake. `tvalid` and `tready` form the transfer on a rising edge where both are high. The block registers its ready outputs, so there is no combinational path from any `tvalid` to its `tready`, and no offer is withdrawn after it is made. All three input streams must carry exactly 512 beats; the block counts beats and ignores extra beats until the next verification is armed. The output stream presents 512 beats with `m_tlast` on the last one and holds `m_tdata` stable while `m_tready` is low.

---

## 3. Architecture

```
   u[511:0] (NTT) ----> u_ram ----+
                                  |   s1_ntt[i] = (u[i] - s2_ntt[i]*h[i]) mod q
   h[511:0] (NTT) ----> h_ram ----+   ----------> work_ram
                                  |
   s2[511:0] (time) -> + twist -> bit-reversed store -> forward NTT -> work_ram
                          |
                          +--> accumulate ||s2||^2 during load

   work_ram -> pointwise with u_ram/h_ram -> inverse NTT -> bit-reversed untwisted read
                                                          |
                                                          +--> accumulate ||s1||^2
                                                          +--> m_axis_s1 stream
                                                          +--> compare with BETA_SQ
```

The three input streams are written into three single-port coefficient memories while their norms and twists are computed. The working polynomial is stored bit-reversed on load, which lets the NTT controller use an in-place Cooley-Tukey butterfly without a separate permutation pass. The inverse transform reads back through the same reversed address map and applies the inverse twist during the result stream.

A single butterfly engine is reused for all 4,608 butterflies. One butterfly needs two coefficient reads, one modular multiply for the twiddle, and two modular additions; those are kept inside one pipeline stage so the logic between registers stays short.

---

## 4. NTT engine

The forward transform uses the negacyclic twist `a'_i = a_i * PSI^i mod Q`, followed by a 512-point radix-2 NTT with the primitive 512th root `OMEGA = PSI^2`. The inverse transform uses the inverse-root stages, the same bit-reversal map, division by `N`, and the inverse twist.

For stage `s = 1..9` the butterfly length is `L = 2^s`, the twiddle step is `OMEGA^(N/L)`, group `g` and offset `k` address `idx0 = g*L + k` and `idx1 = idx0 + L/2`, and the butterfly is

```
  tmp = b * w mod Q
  a' = (a + tmp) mod Q
  b' = (a - tmp) mod Q
```

There are exactly 256 butterflies per stage and 9 stages, so one transform is 2,304 butterflies. The controller keeps the stage, butterfly index, group twiddle and current `w` as state; `w` is reset at each group boundary.

Modular multiplication uses a fixed Barrett reduction with `m = floor(2^28 / Q) = 21843` and at most two corrective subtractions. This keeps the multiplier to one constant-coefficient product plus a few comparator levels, with no variable-latency divider in hardware.

---

## 5. Norm and verdict

The squared norm accumulates one term per coefficient for `s2` during the load stream and one term for `s1` during the result stream. Coefficients are converted to the symmetric representation `[-6144, 6144]` before squaring. The accumulator is 40 bits wide because the largest possible sum exceeds 32 bits. The verdict is inclusive: `accept = (norm_sq <= BETA_SQ)`. No exceptions, false paths or multicycle constraints are used to relax this path.

---

## 6. Standards basis and scope

| Item | Value | Source |
|---|---|---|
| Prime `q` | 12289 | supplied document, §8.6 and Table 8.2 |
| Degree `n` | 512 | supplied document, Algorithm 8.26 |
| Ring | `Z_q[x]/(x^n + 1)` | supplied document, §8.6 |
| `beta^2` | 34,034,726 | supplied document, Table 8.2 |
| Verification equation | `s1 = u - s2*h`, accept if `||(s1,s2)||^2 <= floor(beta^2)` | supplied document, Algorithm 8.26 |
| NTT root | `psi = 10302 = 11^12 mod q`, `psi^512 = -1 mod q` | derived from `q-1 = 2^12 * 3` as stated in §8.6 |

The hash `u = H(h, r, M)` (Algorithm 8.26 step 2), the 320-bit salt, and the byte decompression of the Falcon signature and public key are outside this block. The block receives their already-decoded coefficient streams. This boundary is deliberate: it makes the arithmetic independently testable and keeps a SHAKE implementation from being mixed into a datapath verification.

The supplied document notes that Falcon is being standardised as FN-DSA in FIPS 206 and that the standard was not final at the time of writing. As of 2026-11-25 no public FIPS 206 draft was available, and public IETF material states that FN-DSA is not compatible with the submitted Falcon scheme. This block therefore implements the **Falcon-512 parameters published in the supplied document**, not a claim of FIPS 206 conformance. Re-targeting to the final standard, when published, is a parameter-and-KAT update tracked as a suggested item in `REQUIREMENTS.md`.

---

## 7. Reset and clocking

One clock. `axi_st_areset_n` asynchronously clears control state, beat counters, the verdict registers and output-valid registers. Coefficient memories are not reset; their contents are meaningless until a fresh stream has written all 512 beats, which the controller enforces before it starts a transform. This follows the rule that wide datapath storage should not carry unnecessary asynchronous reset when valid state already says whether the data is meaningful.

---

## 8. Memories

| Memory | Width | Depth | Read latency | Write latency | Purpose |
|---|---|---|---|---|---|
| `u_ram` | 16 | 512 | 1 cycle | 1 cycle | NTT-domain hash target |
| `h_ram` | 16 | 512 | 1 cycle | 1 cycle | NTT-domain public key |
| `work_ram` | 16 | 512 | 1 cycle | 1 cycle | Twisted `s2`, then `s1_ntt`, then `s1` |

All three are inferred synchronous arrays. There are no initial blocks and no hardcoded key material.

---

## 9. Latency

| Stage | Operation | Latency | Cumulative |
|---|---|---|---|
| S0 | Load three 512-beat streams | 512 cycles | 512 |
| S1 | Forward NTT of `s2` | 2,304 cycles | 2,816 |
| S2 | Pointwise `u - s2*h` | 512 cycles | 3,328 |
| S3 | Inverse NTT of `s1_ntt` | 2,304 cycles | 5,632 |
| S4 | Result stream and norm accumulation | 512 cycles | 6,144 |

The measured fixed cost from the last accepted input beat to the verdict pulse is 5,632 cycles; the table's cumulative column includes the 512 load beats. Backpressure on the output stream adds wait cycles and is reported separately in the verification report.

---

## 10. Elaboration checks and simulation-only code

The root constants are checked in an unguarded `initial` block with `$fatal`: `N` must be 512, `Q` must be 12289, `PSI^512 mod Q` must equal `Q-1`, `PSI*PSI_INV mod Q` must equal 1, and `DATA_W` must be at least 14. Protocol and overflow checks (stream beat counts, coefficient range, accumulator range) are guarded by `RTL_SIM` and never drive hardware.

---

## 11. Verification strategy

The test plan is `falcon512_testplan.md`. It uses an independent schoolbook reference model in the testbench, so the NTT is checked against a different algorithm rather than against itself. Cases cover the negacyclic wrap sign, the inclusive norm boundary, random known-answer vectors, and backpressure. Results are recorded in `falcon512_verification.md`.

---

## 12. File inventory

| File | Role |
|---|---|
| `rtl/falcon512_pkg.sv` | shared constants and coefficient helper functions |
| `rtl/falcon512_ntt.sv` | reusable 512-point forward/inverse NTT engine |
| `rtl/falcon512_verify.sv` | top-level controller, memories, pointwise stage and norm check |
| `sim/tb_falcon512_verify.sv` | self-checking testbench with transform-based input generation, schoolbook reference model and KAT cases |
| `sim/f_list.f`, `sim/run.ps1`, `sim/run.sh` | compile list and run scripts |

---

## 13. Assumptions to double-check

- `u` and `h` arrive in NTT-domain order with coefficients already reduced into `[0, Q-1]`.
- `s2` arrives as a signed balanced integer per coefficient, i.e. after Falcon byte decompression.
- The `beta^2` bound in Table 8.2 is applied to both `s1` and `s2` in the symmetric representation, as Algorithm 8.26 states.
