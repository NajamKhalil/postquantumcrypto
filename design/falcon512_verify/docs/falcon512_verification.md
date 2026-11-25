# Falcon-512 Verify Core - Verification Report

| | |
|---|---|
| DUT | `falcon512_verify` and `falcon512_ntt` |
| Author | desktop-ifrf24e\najam |
| Bench | `sim/tb_falcon512_verify.sv` |
| Date | 2026-11-25 |
| Status | SIM PASS, REGRESSION PASS, LINT clean, SYNTH clean, M1-M5 killed |

This report records the real tool output first, then the measured interpretation.
Nothing in sections 2-4 is used in place of the raw logs in section 1.

---

## 1. Raw tool output

### 1.1 Simulation - `sim/sim.log`

```text
../rtl/falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
../rtl/falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  seed=7919  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=15838  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=23757  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  seed=31676  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  seed=39595  bp=0  gap=0  latency=12296  norm=13124735354  accept=0  mismatches=0
RUN 6  CASE T5  seed=47514  bp=0  gap=0  latency=12296  norm=13191523991  accept=0  mismatches=0
RUN 7  CASE T5  seed=55433  bp=0  gap=0  latency=12296  norm=12830286481  accept=0  mismatches=0
RUN 8  CASE T3  seed=63352  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=0
RESULT  = PASS
tb_falcon512_verify.sv:593: $finish called at 1107095 (1s)
```

The `sorry` and `$error` messages are Icarus limitations on simulation-only
constructs. They are not `%Error` lines. The five `$error` messages in the top
level and three in the NTT are inside `RTL_SIM`-guarded protocol checks, so they
never drive hardware.

### 1.2 Regression - `sim/regress.log`

```text
../rtl/falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
../rtl/falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
../rtl/falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
# CONFIG seed-sweep-a  +REGRESS=1 +SEED=101 +SEED_COUNT=4 +BP=0
RUN 1  CASE T1  seed=8020  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=15939  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=23858  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  seed=31777  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  seed=39696  bp=0  gap=0  latency=12296  norm=13298352407  accept=0  mismatches=0
RUN 6  CASE T5  seed=47615  bp=0  gap=0  latency=12296  norm=13023489311  accept=0  mismatches=0
RUN 7  CASE T5  seed=55534  bp=0  gap=0  latency=12296  norm=13014664072  accept=0  mismatches=0
RUN 8  CASE T3  seed=63453  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=0
RUN 9  CASE T7  seed=71372  bp=0  gap=0  latency=12296  norm=1350  accept=1  mismatches=0
RUN 10  CASE T8  seed=79291  bp=0  gap=0  latency=12296  norm=10254  accept=1  mismatches=0
RUN 11  CASE T9  seed=87210  bp=0  gap=0  latency=12296  norm=34034063  accept=1  mismatches=0
RUN 12  CASE T10  seed=95129  bp=0  gap=0  latency=12296  norm=34035128  accept=0  mismatches=0
RUN 13  CASE T5  seed=103048  bp=1  gap=0  latency=12302  norm=12998768382  accept=0  mismatches=0
RUN 14  CASE T5  seed=110967  bp=2  gap=0  latency=12302  norm=13541100248  accept=0  mismatches=0
RUN 15  CASE T5  seed=118886  bp=3  gap=0  latency=12552  norm=12886227861  accept=0  mismatches=0
RUN 16  CASE T7  seed=126805  bp=4  gap=1  latency=12327  norm=1350  accept=1  mismatches=0
RUN 17  CASE T5  seed=942662  bp=0  gap=0  latency=12296  norm=13857753380  accept=0  mismatches=0
RUN 18  CASE T5  seed=1047391  bp=0  gap=0  latency=12296  norm=12817442702  accept=0  mismatches=0
RUN 19  CASE T5  seed=1152120  bp=0  gap=0  latency=12296  norm=13117718763  accept=0  mismatches=0
RUN 20  CASE T5  seed=1256849  bp=0  gap=0  latency=12296  norm=13223065068  accept=0  mismatches=0
RESULT  = PASS
tb_falcon512_verify.sv:593: $finish called at 2778325 (1s)
CONFIG seed-sweep-a  PASS  runs=20
# CONFIG seed-sweep-b  +REGRESS=1 +SEED=202 +SEED_COUNT=2 +BP=2
RUN 1  CASE T1  seed=8121  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=16040  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=23959  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  seed=31878  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  seed=39797  bp=0  gap=0  latency=12296  norm=13547460495  accept=0  mismatches=0
RUN 6  CASE T5  seed=47716  bp=0  gap=0  latency=12296  norm=13162227405  accept=0  mismatches=0
RUN 7  CASE T5  seed=55635  bp=0  gap=0  latency=12296  norm=13211592109  accept=0  mismatches=0
RUN 8  CASE T3  seed=63554  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=0
RUN 9  CASE T7  seed=71473  bp=0  gap=0  latency=12296  norm=1350  accept=1  mismatches=0
RUN 10  CASE T8  seed=79392  bp=0  gap=0  latency=12296  norm=9985  accept=1  mismatches=0
RUN 11  CASE T9  seed=87311  bp=0  gap=0  latency=12296  norm=34034063  accept=1  mismatches=0
RUN 12  CASE T10  seed=95230  bp=0  gap=0  latency=12296  norm=34035128  accept=0  mismatches=0
RUN 13  CASE T5  seed=103149  bp=1  gap=0  latency=12302  norm=13559552785  accept=0  mismatches=0
RUN 14  CASE T5  seed=111068  bp=2  gap=0  latency=12302  norm=12614020090  accept=0  mismatches=0
RUN 15  CASE T5  seed=118987  bp=3  gap=0  latency=12552  norm=12523263010  accept=0  mismatches=0
RUN 16  CASE T7  seed=126906  bp=4  gap=1  latency=12327  norm=1350  accept=1  mismatches=0
RUN 17  CASE T5  seed=942763  bp=2  gap=0  latency=12302  norm=12648704217  accept=0  mismatches=0
RUN 18  CASE T5  seed=1047492  bp=2  gap=0  latency=12302  norm=12274025472  accept=0  mismatches=0
RESULT  = PASS
tb_falcon512_verify.sv:593: $finish called at 2501685 (1s)
CONFIG seed-sweep-b  PASS  runs=18
# CONFIG seed-sweep-c  +REGRESS=1 +SEED=303 +SEED_COUNT=2 +BP=3
RUN 1  CASE T1  seed=8222  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=16141  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=24060  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  seed=31979  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  seed=39898  bp=0  gap=0  latency=12296  norm=12082497384  accept=0  mismatches=0
RUN 6  CASE T5  seed=47817  bp=0  gap=0  latency=12296  norm=12627260758  accept=0  mismatches=0
RUN 7  CASE T5  seed=55736  bp=0  gap=0  latency=12296  norm=13675823368  accept=0  mismatches=0
RUN 8  CASE T3  seed=63655  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=0
RUN 9  CASE T7  seed=71574  bp=0  gap=0  latency=12296  norm=1350  accept=1  mismatches=0
RUN 10  CASE T8  seed=79493  bp=0  gap=0  latency=12296  norm=9656  accept=1  mismatches=0
RUN 11  CASE T9  seed=87412  bp=0  gap=0  latency=12296  norm=34034063  accept=1  mismatches=0
RUN 12  CASE T10  seed=95331  bp=0  gap=0  latency=12296  norm=34035128  accept=0  mismatches=0
RUN 13  CASE T5  seed=103250  bp=1  gap=0  latency=12302  norm=12986877522  accept=0  mismatches=0
RUN 14  CASE T5  seed=111169  bp=2  gap=0  latency=12302  norm=12938217898  accept=0  mismatches=0
RUN 15  CASE T5  seed=119088  bp=3  gap=0  latency=12552  norm=12816349157  accept=0  mismatches=0
RUN 16  CASE T7  seed=127007  bp=4  gap=1  latency=12327  norm=1350  accept=1  mismatches=0
RUN 17  CASE T5  seed=942864  bp=3  gap=0  latency=12552  norm=12860905221  accept=0  mismatches=0
RUN 18  CASE T5  seed=1047593  bp=3  gap=0  latency=12552  norm=12822251430  accept=0  mismatches=0
RESULT  = PASS
tb_falcon512_verify.sv:593: $finish called at 2506685 (1s)
CONFIG seed-sweep-c  PASS  runs=18
REGRESSION  = PASS   (3 configurations, 56 runs)
```

`sim/regress.ps1` compiled the bench once, then ran three configurations with
different `+SEED`, `+SEED_COUNT` and `+BP` plusargs. Each configuration has one
`RESULT  = PASS` line and no `%Error` line. The summary line reports 56 runs.

### 1.3 Lint - `lint/lint.log`

```text
..\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
lint: clean (0 errors)
```

This compile was made without `RTL_SIM`, using `-s falcon512_verify`. The last
line is the runner's exit-status annotation; the first line is the unedited
Icarus message.

### 1.4 Synthesis - `synth/synth_probe.log`

```text
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
register lists before later technology mapping.

### 1.5 Mutation campaign - `sim/mutation.rpt`

```text
# mutation campaign 2026-11-25 11:19:53
# source: G:\Git\postquantumcrypto\design\falcon512_verify
# copies: C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut
# M1 inverse stage 9 root replaced by forward root
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  seed=7919  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=15838  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=6
RUN 3  CASE T3  seed=23757  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=12
RUN 4  CASE T4  seed=31676  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=17
RUN 5  CASE T5  seed=39595  bp=0  gap=0  latency=12296  norm=13124735354  accept=0  mismatches=528
RUN 6  CASE T5  seed=47514  bp=0  gap=0  latency=12296  norm=13191523991  accept=0  mismatches=1039
RUN 7  CASE T5  seed=55433  bp=0  gap=0  latency=12296  norm=12830286481  accept=0  mismatches=1550
RUN 8  CASE T3  seed=63352  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=1556
RESULT  = FAIL   (1556 mismatch(es))
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\sim\tb_falcon512_verify.sv:593: $finish called at 1107095 (1s)
KILLED   M1 - inverse stage 9 root replaced by forward root
# M2 negacyclic wrap sign removed from reference model
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  seed=7919  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=15838  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=23757  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  seed=31676  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  seed=39595  bp=0  gap=0  latency=12296  norm=13124735354  accept=0  mismatches=512
RUN 6  CASE T5  seed=47514  bp=0  gap=0  latency=12296  norm=13191523991  accept=0  mismatches=1024
RUN 7  CASE T5  seed=55433  bp=0  gap=0  latency=12296  norm=12830286481  accept=0  mismatches=1536
RUN 8  CASE T3  seed=63352  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=1536
RESULT  = FAIL   (1536 mismatch(es))
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\sim\tb_falcon512_verify.sv:593: $finish called at 1107095 (1s)
KILLED   M2 - negacyclic wrap sign removed from reference model
# M3 inclusive norm comparison changed to exclusive
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  seed=7919  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=15838  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=23757  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=1
RUN 4  CASE T4  seed=31676  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=1
RUN 5  CASE T5  seed=39595  bp=0  gap=0  latency=12296  norm=13124735354  accept=0  mismatches=1
RUN 6  CASE T5  seed=47514  bp=0  gap=0  latency=12296  norm=13191523991  accept=0  mismatches=1
RUN 7  CASE T5  seed=55433  bp=0  gap=0  latency=12296  norm=12830286481  accept=0  mismatches=1
RUN 8  CASE T3  seed=63352  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=2
RESULT  = FAIL   (2 mismatch(es))
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\sim\tb_falcon512_verify.sv:593: $finish called at 1107095 (1s)
KILLED   M3 - inclusive norm comparison changed to exclusive
# M4 butterfly count shortened by one
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  seed=7919  bp=0  gap=0  latency=12292  norm=0  accept=1  mismatches=1
RUN 2  CASE T2  seed=15838  bp=0  gap=0  latency=12292  norm=84  accept=1  mismatches=516
RUN 3  CASE T3  seed=23757  bp=0  gap=0  latency=12292  norm=34034726  accept=1  mismatches=517
RUN 4  CASE T4  seed=31676  bp=0  gap=0  latency=12292  norm=34044125  accept=0  mismatches=518
RUN 5  CASE T5  seed=39595  bp=0  gap=0  latency=12292  norm=13124735354  accept=0  mismatches=1032
RUN 6  CASE T5  seed=47514  bp=0  gap=0  latency=12292  norm=13191523991  accept=0  mismatches=1546
RUN 7  CASE T5  seed=55433  bp=0  gap=0  latency=12292  norm=12830286481  accept=0  mismatches=2060
RUN 8  CASE T3  seed=63352  bp=1  gap=0  latency=12298  norm=34034726  accept=1  mismatches=2060
RESULT  = FAIL   (2060 mismatch(es))
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\sim\tb_falcon512_verify.sv:593: $finish called at 1106775 (1s)
KILLED   M4 - butterfly count shortened by one
# M5 PSI^i twist removed from loaded s2
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:80: sorry: constant selects in always_* processes are not currently supported (all bits will be included).
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:359: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:363: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:368: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:373: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_verify.sv:377: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:227: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:230: warning: System task ($error) cannot be synthesized in an always_ff process.
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\rtl\falcon512_ntt.sv:233: warning: System task ($error) cannot be synthesized in an always_ff process.
RUN 1  CASE T1  seed=7919  bp=0  gap=0  latency=12296  norm=0  accept=1  mismatches=0
RUN 2  CASE T2  seed=15838  bp=0  gap=0  latency=12296  norm=84  accept=1  mismatches=0
RUN 3  CASE T3  seed=23757  bp=0  gap=0  latency=12296  norm=34034726  accept=1  mismatches=0
RUN 4  CASE T4  seed=31676  bp=0  gap=0  latency=12296  norm=34044125  accept=0  mismatches=0
RUN 5  CASE T5  seed=39595  bp=0  gap=0  latency=12296  norm=13124735354  accept=0  mismatches=513
RUN 6  CASE T5  seed=47514  bp=0  gap=0  latency=12296  norm=13191523991  accept=0  mismatches=1026
RUN 7  CASE T5  seed=55433  bp=0  gap=0  latency=12296  norm=12830286481  accept=0  mismatches=1539
RUN 8  CASE T3  seed=63352  bp=1  gap=0  latency=12302  norm=34034726  accept=1  mismatches=1539
RESULT  = FAIL   (1539 mismatch(es))
C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut\sim\tb_falcon512_verify.sv:593: $finish called at 1107095 (1s)
KILLED   M5 - PSI^i twist removed from loaded s2
MUTATION  = PASS   (5 killed, 0 survived)
```

Each mutant was compiled and run from a fresh copy under
`C:\Users\najam\AppData\Local\Temp\opencode\falcon_regress_mut`. The repository
RTL and bench were restored before every mutation and were never modified by the
campaign. The runner classifies from the bench's `RESULT` token because `vvp`
itself exits zero after `$finish`.

---

## 2. Measured results

| ID | Status | Measured outcome |
|---|---|---|
| T1 | PASS | 512 zero `s1` beats, norm `0`, accept, latency `12296` |
| T2 | PASS | negacyclic wrap case, norm `84`, accept, latency `12296` |
| T3 | PASS | inclusive boundary, norm `34034726`, accept, latency `12296` |
| T4 | PASS | first rejected norm, norm `34044125`, reject, latency `12296` |
| T5 | PASS | three seeded dense vectors per configuration, all coefficients checked, computed norm and verdict match |
| T6 | PASS | T3 replay with output pattern 1, norm `34034726`, accept, latency `12302`, held data stable |
| T7 | PASS | non-zero `s2*h` accept path, norm `1350`, accept, latency `12296` |
| T8 | PASS | dense low-amplitude accept vectors; measured norms `10254`, `9985` and `9656`, all accept |
| T9 | PASS | dense near-boundary accept, norm `34034063`, 663 below the bound |
| T10 | PASS | dense near-boundary reject, norm `34035128`, 402 above the bound |
| T11 | PASS | eight seed-sweep runs across three configurations, all coefficients, norms and verdicts match |
| T12 | PASS | output patterns 2 and 3, latencies `12302` and `12552`, no lost, duplicated or mutated beats |
| T13 | PASS | T7 vector with input gaps and output pattern 4, norm `1350`, accept, latency `12327` |

| ID | Status | Fault | Mismatches |
|---|---|---|---|
| M1 | KILLED | inverse stage 9 root changed from `2859` to `3400` | 1556 |
| M2 | KILLED | schoolbook wrap sign changed from `-1` to `+1` | 1536 |
| M3 | KILLED | `norm_q <= BETA_SQ_Q` changed to `<` | 2 |
| M4 | KILLED | last butterfly index shortened by one | 2060 |
| M5 | KILLED | loaded `s2` no longer multiplied by `PSI^i` | 1539 |

The measured latency from the last accepted input beat to the verdict is
`12296` clocks when neither input gaps nor output backpressure are applied.
Output patterns 1 and 2 add 6 cycles, pattern 3 adds 256 cycles, and input gaps
plus pattern 4 add 31 cycles. Adding the 512 input beats gives `12808` clocks
for an unstalled verification.

The regression suite adds 8 seed-sweep runs and 3 configurations of the fixed
accept, reject, boundary and backpressure cases: 56 runs in total. The canonical
`sim/run.ps1` sweep remains the 8-run check used by the dashboard SIM gate.

---

## 3. Scope and limitations

The hash `u = H(h, r, M)`, the Falcon salt, byte decompression, key generation
and signing are outside this block. The bench drives decoded coefficient streams
and checks the ring arithmetic, norm decision and protocol behaviour only.

No FIPS 206 conformance is claimed. The supplied document describes Falcon-512;
public material available on 2026-11-25 states that FN-DSA is not compatible with
the submitted Falcon scheme and no public FIPS 206 draft was available. The
constants and expected vectors in this report are the published Falcon-512
values from the supplied PDF.

The `CDC`, `TIMING` and `FPV` gates are deliberately left grey. This design has
one clock and one asynchronous reset, and no CDC, STA, PnR or formal tool is
installed in this environment. No timing number or formal proof is reported.
Regression checks cycle counts and protocol stability, not nanosecond timing.

---

## 4. Reproduction commands

From `design/falcon512_verify/sim`:

```text
powershell -NoProfile -ExecutionPolicy Bypass -File .\run.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\regress.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File .\mutation.ps1
```

The canonical runner writes `sim.log`, the regression runner writes
`regress.log`, and the mutation runner writes `mutation.rpt`. The mutation
runner keeps all mutant copies outside the repository and deletes them after
the run.

From `design/falcon512_verify/lint`:

```text
C:\iverilog\bin\iverilog.exe -g2012 -s falcon512_verify -o C:\Users\najam\AppData\Local\Temp\opencode\falcon_lint_exe ..\rtl\falcon512_pkg.sv ..\rtl\falcon512_ntt.sv ..\rtl\falcon512_verify.sv
```

From `design/falcon512_verify/synth`:

```text
C:\Users\najam\AppData\Local\Programs\Python\Python312\Scripts\yowasp-yosys.exe -q -s synth_probe.ys
```