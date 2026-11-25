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
off by one stage, a norm accumulator that overflows silently, and a ready/valid
handshake that drops a coefficient. A single vector with all-zero coefficients
cannot expose any of them, so the bench runs six shapes in one reset-to-result
sweep and checks every output beat against an independently built expectation.

The input generator builds time-domain `u_time`, `h_time` and `s2_time`, then
forms the NTT-domain `u` and `h` streams with a testbench transform. The
expected `s1_time` is either chosen directly before encoding (bounded cases) or
computed by a schoolbook negacyclic multiply (random cases). The DUT cannot pass
by repeating its own NTT: the expectation comes from a different path.

### 1.2 Reference and error accounting

Every output beat is compared with the expected coefficient in the same cycle
in which `m_tvalid` and `m_tready` are high. The verdict and the 40-bit norm are
checked on the verdict pulse. One `mismatch` counter collects every kind of
failure: coefficient, norm, accept bit, missing verdict, extra verdict and
watchdog expiry. The final log line is the only pass/fail contract:
`RESULT  = PASS` with zero mismatches, otherwise `RESULT  = FAIL`.

`RTL_SIM` is defined for the simulation build so the range and beat-count checks
inside the RTL are compiled. The lint and synthesis builds do not define it.

---

## 2. Cases

This table is the complete case list; the report adds the measured status.

| ID | What is proven | Stimulus | Expected |
|---|---|---|---|
| T1 | Empty-vector identity | `u_time = h_time = s2_time = 0`, 512 beats on all three streams | 512 zero `s1` beats, norm `0`, accept |
| T2 | Negacyclic wrap sign | `s2_time[0] = 1`, `h_time[511] = 1`, sparse `s1_time`; the product coefficient at index 511 is `-1` | `s1` equals the chosen sparse vector; wrong wrap sign cannot match |
| T3 | Inclusive norm boundary | `s1_time = {2483, 2406, 4699}` at indices `{0, 1, 2}`, `s2_time = 0`; `2483^2 + 2406^2 + 4699^2 = 34,034,726` | norm exactly `34034726`, accept |
| T4 | First rejected norm | Same as T3 with the third coefficient raised to `4700` | norm `34044125`, reject |
| T5 | Random known-answer vectors | Three seeded vectors with dense `s2` and `h`, expectation from schoolbook multiply | every coefficient and norm matches; accept or reject follows the computed norm |
| T6 | Output backpressure | Re-run T3 with `m_tready` held low for four beats at the start and two beats mid-stream | norm `34034726`, accept; data held stable, no beats lost, verdict coincident with final accepted beat |

### 2.1 Seeding and replay

Random vectors use a fixed local pseudo-random sequence seeded per vector, so a
failure can be replayed without a plusarg or an external file. The bounded cases
T1-T4 use literal coefficient values rather than randomness.

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

---

## 4. Mutation plan

This table names the faults the final verification report must try. Each mutant
is applied to a copy of the RTL, never to the committed source, and the bench is
expected to print `RESULT  = FAIL`.

| ID | Mutation | Expected result |
|---|---|---|
| M1 | Flip the inverse NTT twiddle at stage 9 to the forward root | Coefficient mismatch |
| M2 | Drop the negacyclic sign on the wrap in the testbench generator's schoolbook path | Boundary/random mismatch |
| M3 | Change the norm comparison from `<=` to `<` | T3 flips from accept to reject |
| M4 | Drop one cycle from the inverse NTT butterfly count | Coefficient and norm mismatch |
| M5 | Remove the `PSI^i` twist from the loaded `s2` | Coefficient mismatch |

### 4.1 Why these mutations

They cover the five ways a "passing" bench can be blind: a twiddle error, a sign
error, an off-by-one boundary, a stage-count error and a missing pre-transform
twist. A mutant that still passes is reported as `SURVIVED`, not hidden.

---

## 5. Evidence to collect

This table maps each gate to the artifact the run writes.

| Gate | Artifact | Read-back |
|---|---|---|
| SIM | `sim/sim.log` | One `RESULT  = PASS` line and zero `%Error` lines |
| LINT | `lint/lint.log` | `0 errors`, produced without `RTL_SIM` |
| SYNTH | `synth/synth.log` | Yosys completion with `0 errors` |
| DOCS | the three files in `docs/` | Present, well formed and newer than the RTL |
| FEAT | `REQUIREMENTS.md` | All required rows `DONE` |

---

## 6. File map

This table lists the three documents that make up the deliverable.

| Document | Role |
|---|---|
| `docs/falcon512_verify_design_spec.md` | Architecture, interface, constants and scope |
| `docs/falcon512_testplan.md` | Cases, mutation plan and evidence contract |
| `docs/falcon512_verification.md` | Raw outputs, measured results and limitations |
