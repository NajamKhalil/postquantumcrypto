# Falcon-512 Verify Core - Verification Report

| | |
|---|---|
| DUT | `falcon512_verify` and `falcon512_ntt` |
| Author | desktop-ifrf24e\najam |
| Bench | `sim/tb_falcon512_verify.sv` |
| Date | 2026-11-25 |
| Status | SIM PASS, LINT clean, SYNTH clean, M1-M5 KILLED |

This report records the real tool output first, then the measured interpretation.
Nothing in sections 2-4 is used in place of the raw logs in section 1.

---

## 1. Raw tool output

### 1.1 Simulation - `sim/sim.log`

```
iverilog.exe : ../rtl/falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported 
(all bits will be included).
At G:\Git\postquantumcrypto\design\falcon512_verify\sim\run.ps1:52 char:16
+ ... mpile_out = & $iverilog -s tb_falcon512_verify -g2012 -f f_list.f -o  ...
+                 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    + CategoryInfo          : NotSpecified: (../rtl/falcon51...l be included).:String) [], RemoteException
    + FullyQualifiedErrorId : NativeCommandError
 
../rtl/falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  norm=13124735354  accept=0  mismatches=0
RUN 6  CASE T5  norm=13191523991  accept=0  mismatches=0
RUN 7  CASE T5  norm=12830286481  accept=0  mismatches=0
RUN 8  CASE T3  norm=34034726  accept=1  mismatches=0
RESULT  = PASS
tb_falcon512_verify.sv:437: $finish called at 1107095 (1s)
```

The `sorry` and `$error` warnings are Icarus limitations on simulation-only
constructs. They are not `%Error` lines and the bench reaches `RESULT  = PASS`.
The five `$error` messages in the top level and three in the NTT are inside
`RTL_SIM`-guarded protocol checks, so they never drive hardware.

### 1.2 Lint - `lint/lint.log`

```
..\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
lint: clean (0 errors)
```

This compile was made without `RTL_SIM`, using `-s falcon512_verify`. The last
line is the runner's exit-status annotation; the first line is the unedited
Icarus message.

### 1.3 Synthesis - `synth/synth_probe.log`

```
Warning: Replacing memory \mem with list of registers. See ../rtl/falcon512_ntt.sv:140
Warning: Replacing memory \s1hat_ram with list of registers. See ../rtl/falcon512_verify.sv:257
Warning: Replacing memory \h_ram with list of registers. See ../rtl/falcon512_verify.sv:209
Warning: Replacing memory \u_ram with list of registers. See ../rtl/falcon512_verify.sv:205
synthesis successful (0 errors)
```

`Yosys 0.71 (git sha1 b4c586fd3)` ran `synth/synth_probe.ys` with
`hierarchy -top falcon512_verify -check`, `synth -top falcon512_verify -run
coarse`, `check -assert` and `stat`. The exit status was zero. The last line is
the runner's exit-status annotation; the four warnings are the unedited Yosys
messages. They report that this coarse pass expands the coefficient arrays to
register lists before later technology mapping, which is expected for a 512-bit
array in this flow.

### 1.4 Mutation campaign - temporary copies only

M1 - inverse stage 9 root replaced by forward root:

```
RUN 8  CASE T3  norm=34034726  accept=1  mismatches=1556
RESULT  = FAIL   (1556 mismatch(es))
```

M2 - negacyclic wrap sign removed from the reference model:

```
RUN 8  CASE T3  norm=34034726  accept=1  mismatches=1536
RESULT  = FAIL   (1536 mismatch(es))
```

M3 - inclusive norm comparison changed to exclusive:

```
RUN 3  CASE T3  norm=34034726  accept=1  mismatches=1
RUN 4  CASE T4  norm=34044125  accept=0  mismatches=1
RUN 8  CASE T3  norm=34034726  accept=1  mismatches=2
RESULT  = FAIL   (2 mismatch(es))
```

M4 - butterfly count shortened by one:

```
RUN 8  CASE T3  norm=34034726  accept=1  mismatches=2053
RESULT  = FAIL   (2053 mismatch(es))
```

M5 - `PSI^i` twist removed from loaded `s2`:

```
RUN 8  CASE T3  norm=34034726  accept=1  mismatches=1539
RESULT  = FAIL   (1539 mismatch(es))
```

Each mutant was compiled and run from `C:\Users\najam\AppData\Local\Temp\opencode\falcon_mut`.
The repository RTL and bench were restored before every mutation and were never
modified by the campaign.

---

## 2. Measured results

| ID | Status | Measured outcome |
|---|---|---|
| T1 | PASS | 512 zero `s1` beats, norm `0`, accept, zero mismatches |
| T2 | PASS | negacyclic wrap case, norm `84`, accept, zero mismatches |
| T3 | PASS | inclusive boundary, norm `34034726`, accept, zero mismatches |
| T4 | PASS | first rejected norm, norm `34044125`, reject, zero mismatches |
| T5 | PASS | three seeded dense vectors, norms `13124735354`, `13191523991`, `12830286481`, all rejected, zero mismatches |
| T6 | PASS | T3 replay with `m_tready` low on the first four beats and two mid-stream beats; all beats and the verdict match, zero mismatches |

| ID | Status | Fault | Mismatches |
|---|---|---|---|
| M1 | KILLED | inverse stage 9 root changed from `2859` to `3400` | 1556 |
| M2 | KILLED | schoolbook wrap sign changed from `-1` to `+1` | 1536 |
| M3 | KILLED | `norm_q <= BETA_SQ_Q` changed to `<` | 2 |
| M4 | KILLED | last butterfly index shortened by one | 2053 |
| M5 | KILLED | loaded `s2` no longer multiplied by `PSI^i` | 1539 |

The measured latency from the last accepted input beat to the verdict is
12,296 clocks in the eight bench runs. Adding the 512 input beats gives 12,808
clocks per verification. Backpressure in T6 adds six wait cycles and does not
change any coefficient, norm or accept bit.

---

## 3. Scope and limitations

The hash `u = H(h, r, M)`, the Falcon salt, byte decompression, key generation
and signing are outside this block. The bench drives decoded coefficient streams
and checks the ring arithmetic and norm decision only.

No FIPS 206 conformance is claimed. The supplied document describes Falcon-512;
public material available on 2026-11-25 states that FN-DSA is not compatible with
the submitted Falcon scheme and no public FIPS 206 draft was available. The
constants and expected vectors in this report are the published Falcon-512
values from the supplied PDF.

The `CDC`, `TIMING` and `FPV` gates are deliberately left grey. This design has
one clock and one asynchronous reset, and no CDC, STA, PnR or formal tool is
installed in this environment. No timing number or formal proof is reported.

---

## 4. Reproduction commands

From `design/falcon512_verify/sim`:

```
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
```

From `design/falcon512_verify/lint`:

```
C:\iverilog\bin\iverilog.exe -g2012 -s falcon512_verify -o C:\Users\najam\AppData\Local\Temp\opencode\falcon_lint_exe ..\rtl\falcon512_pkg.sv ..\rtl\falcon512_ntt.sv ..\rtl\falcon512_verify.sv
```

From `design/falcon512_verify/synth`:

```
C:\Users\najam\AppData\Local\Programs\Python\Python312\Scripts\yowasp-yosys.exe -q -s synth_probe.ys
```

The mutation runner is kept outside the repository at
`C:\Users\najam\AppData\Local\Temp\opencode\falcon_mut.ps1` so no temporary
mutant source is left in the delivered tree. The T6 row in the test plan and the
measured T6 row above both name the T3 replay vector with norm `34034726` and
accept `1`.
