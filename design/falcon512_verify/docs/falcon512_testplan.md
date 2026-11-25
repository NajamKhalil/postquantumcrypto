# Falcon-512 Verify Core - Test Plan

| | |
|---|---|
| DUT | `falcon512_verify` (`rtl/falcon512_verify.sv`) and its NTT engine `falcon512_ntt` (`rtl/falcon512_ntt.sv`) |
| Testbench | `sim/tb_falcon512_verify.sv` |
| Simulator | Icarus Verilog |
| Results | `falcon512_verification.md` |

This document says **what has to be proven and how each item is reached**. The
results of running it are in `falcon512_verification.md`, and the architecture
being exercised is described in `falcon512_verify_design_spec.md` section 3.

---

## 1. Strategy

### 1.1 Two DUTs at once

The interesting bugs in this design are **arithmetic identity bugs** and
**stream/control bugs**: a negacyclic wrap with the wrong sign, a twiddle table
off by one stage, a norm accumulator that is wrong but still on the accepted
side of the bound, and a ready/valid handshake that drops or mutates a
coefficient. A single vector with all-zero coefficients cannot expose any of
them.

The bench therefore has two layers:

1. **Canonical sweep** (`sim/run.ps1`): eight fixed runs T1-T6, preserving the
   original acceptance evidence and adding a measured last-beat-to-verdict
   latency check.
2. **Regression sweep** (`sim/regress.ps1`): the same eight runs plus T7-T13
   and four configurable seed-sweep runs, compiled once and executed in three
   deterministic configurations. This is the suite used for regression.

The input generator builds time-domain `u_time`, `h_time` and `s2_time`, then
forms the NTT-domain `u` and `h` streams with a testbench transform. The
expected `s1_time` is either chosen directly before encoding (bounded cases) or
computed by a schoolbook negacyclic multiply (random cases). The DUT cannot pass
by repeating its own NTT: the expectation comes from a different path.

### 1.2 Reference and error accounting

Every output beat is compared with the expected coefficient in the same cycle
in which `m_tvalid` and `m_tready` are high. While `m_tready` is low, `m_tdata`
and `m_tlast` are checked for stability. The verdict and the 40-bit norm are
checked on the verdict pulse. One `mismatch` counter collects every kind of
failure: coefficient, held-data mutation, norm, accept bit, missing verdict,
extra verdict, wrong latency and watchdog expiry. The final log line is the
only pass/fail contract: `RESULT  = PASS` with zero mismatches, otherwise
`RESULT  = FAIL`.

`RTL_SIM` is defined for the simulation build so the range and beat-count checks
inside the RTL are compiled. The lint and synthesis builds do not define it.

---

## 2. Cases

This table is the complete case list; the report adds the measured status.

| ID | What is proven | Stimulus | Expected |
|---|---|---|---|
| T1 | Empty-vector identity | `u_time = h_time = s2_time = 0`, 512 beats on all three streams | 512 zero `s1` beats, norm `0`, accept, latency `12296` |
| T2 | Negacyclic wrap sign | `s2_time[0] = 1`, `h_time[511] = 1`, sparse `s1_time`; the product coefficient at index 511 is `-1` | `s1` equals the chosen sparse vector; wrong wrap sign cannot match |
| T3 | Inclusive norm boundary | `s1_time = {2483, 2406, 4699}` at indices `{0, 1, 2}`, `s2_time = 0`; `2483^2 + 2406^2 + 4699^2 = 34,034,726` | norm exactly `34034726`, accept |
| T4 | First rejected norm | Same as T3 with the third coefficient raised to `4700` | norm `34044125`, reject |
| T5 | Random known-answer vectors | Three seeded vectors with dense `s2` and `h`, expectation from schoolbook multiply | every coefficient and norm matches; reject follows the computed norm |
| T6 | Output backpressure pattern 1 | Re-run T3 with `m_tready` alternating at the first four beats and at beats 250-251 | norm `34034726`, accept; data held stable, no beats lost, verdict coincident with final accepted beat |
| T7 | Accept with a real product | `s2[0]=11`, `s2[1]=-7`, `s2[511]=5`, `h={1,2,3}` at `{0,1,511}`, sparse chosen `s1` | norm `1350`, accept; proves the accept path with non-zero `s2*h` |
| T8 | Dense low-amplitude accept | Seeded `h`, `s2` and `s1` in `[-3,3]`, `[-5,5]`, `[-5,5]`, expectation from schoolbook multiply | accept; norm stays below `beta^2` while all 512 coefficients are exercised |
| T9 | Dense near-boundary accept | `s1[i]=257` for all 512 coefficients, `s1[0]=532`, `s2=0` | norm exactly `34,034,063`, 663 below the bound, accept |
| T10 | Dense near-boundary reject | Same as T9 with `s1[0]=533` | norm exactly `34,035,128`, 402 above the bound, reject |
| T11 | Deterministic seed sweep | Four runs per configuration with `+SEED` and `+SEED_COUNT`; dense `s2`, `h` and `s1` from the LCG, expectation from schoolbook multiply | every coefficient, norm and verdict matches across 8 seed-sweep runs in the regression suite |
| T12 | Output backpressure patterns 2 and 3 | Mid-stream alternating ready at beats 100-105, and a deterministic modulo-3 ready pattern, on dense vectors | no lost or duplicated beats, held data stable, verdict and norm match |
| T13 | Input gaps plus sparse backpressure | T7 vector with two idle clocks before every fourth input beat and output pattern 4 | norm `1350`, accept; no coefficient or latency failure from uneven input timing |

### 2.1 Seeding and replay

Random vectors use a fixed local pseudo-random sequence seeded by
`+SEED=<base>`. A failure can be replayed by reusing the printed `seed` value
with `+REGRESS=1` and `+SEED_COUNT=1`. The bounded cases T1-T4, T7, T9 and T10
use literal coefficient values rather than randomness.

`+BP=<0..4>` changes only the T11 seed-sweep runs, so T6 and T12 keep their
documented patterns. T13 always uses pattern 4 and input gaps. The regression
runner passes three fixed seed bases and backpressure modes; see
`sim/regress.ps1`.

---

## 3. Checks not done here

### 3.1 Hash and decompression are out of scope

`u = H(h, r, M)` and the Falcon byte decoding are not implemented in this block;
the bench drives decoded coefficients directly. That boundary is stated in
`falcon512_verify_design_spec.md` section 6 and is not silently assumed to be
verified here.

### 3.2 Signing and key generation are out of scope

The FFT Gaussian sampler and the Pornin-Prest tower are not present. No claim is
made about signer or key-generator behaviour, and no mutation of those paths is
possible because they do not exist in this DUT.

### 3.3 Timing and CDC are not claimed

This block has one clock and one asynchronous reset. No STA, PnR, CDC or formal
tool is installed, so the corresponding dashboard gates remain grey. The bench
checks cycle counts, not nanosecond timing.

---

## 4. Mutation plan

This table names the faults the final verification report must try. Each mutant
is applied to a copy of the RTL outside the repository by `sim/mutation.ps1`;
the committed source is never changed. The bench is expected to print
`RESULT  = FAIL`.

| ID | Mutation | Expected result |
|---|---|---|
| M1 | Flip the inverse NTT twiddle at stage 9 to the forward root | Coefficient mismatch |
| M2 | Drop the negacyclic sign on the wrap in the testbench generator's schoolbook path | Boundary/random mismatch |
| M3 | Change the norm comparison from `<=` to `<` | T3 flips from accept to reject |
| M4 | Drop one cycle from the inverse NTT butterfly count | Coefficient, norm and latency mismatch |
| M5 | Remove the `PSI^i` twist from the loaded `s2` | Coefficient mismatch |

### 4.1 Why these mutations

They cover the five ways a "passing" bench can be blind: a twiddle error, a sign
error, an off-by-one boundary, a stage-count error and a missing pre-transform
twist. A mutant that still passes is reported as `SURVIVED`, not hidden. The
runner classifies from the bench's `RESULT` token because `vvp` itself exits
zero after `$finish`.

---

## 5. Evidence to collect

This table maps each gate to the artifact the run writes.

| Gate | Artifact | Read-back |
|---|---|---|
| SIM | `sim/sim.log` | One `RESULT  = PASS` line and zero `%Error` lines |
| REGRESSION | `sim/regress.log` | Three `RESULT  = PASS` lines, three `CONFIG ... PASS` lines and `REGRESSION  = PASS` |
| MUTATION | `sim/mutation.rpt` | Five `KILLED` lines and `MUTATION  = PASS` |
| LINT | `lint/lint.log` | `0 errors`, produced without `RTL_SIM` |
| SYNTH | `synth/synth_probe.log` | Yosys completion with `0 errors` |
| DOCS | the three files in `docs/` | Present, well formed and newer than the RTL |
| FEAT | `REQUIREMENTS.md` | All required rows `DONE` |

---

## 6. File map

This table lists the verification deliverables.

| Document or script | Role |
|---|---|
| `docs/falcon512_verify_design_spec.md` | Architecture, interface, constants and scope |
| `docs/falcon512_testplan.md` | Cases, mutation plan and evidence contract |
| `docs/falcon512_verification.md` | Raw outputs, measured results and limitations |
| `sim/run.ps1` | Canonical eight-run sweep |
| `sim/regress.ps1` | Deterministic multi-seed regression sweep |
| `sim/mutation.ps1` | Repeatable M1-M5 campaign on external copies |
