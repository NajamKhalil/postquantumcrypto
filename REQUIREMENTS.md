# Post-Quantum Crypto RTL - Requirements

Checklist extracted from the request and the RTL design methodology. Every item
starts `TODO` and is updated to `DONE` with evidence as work completes. The
`FEAT` gate of `monitor/rtl_monitor.py` reads this file.

| ID | Status | Requirement | Evidence |
|---|---|---|---|
| R1 | DONE | Organise the repository into the methodology skeleton: `rtl/`, `sim/`, `docs/` (+ `docs/diagrams/`), `fpv/`, `synth/`, `vcsmx/`, `lint/`, `cdc/`, `sta/`, with `placeholder` in empty directories | `design/falcon512_verify/` holds every required subdirectory; `git status` confirms placeholders are tracked |
| R2 | DONE | Stand up `monitor/rtl_monitor.py` verbatim from PART 9 section 9 before any RTL; start `--watch`, confirm the block is listed with grey gates | 1639 lines copied verbatim; `--status` reports the block with `0/10` gates; watcher running |
| R3 | DONE | Extract the design requirements from `design/docs/lattice-based-cryptography.pdf` into a cited design specification | `design/falcon512_verify/docs/falcon512_verify_design_spec.md`, sections 1, 6 and 13 cite the PDF |
| R4 | DONE | Install open-source tooling for simulation, lint/synthesis and Python (dashboard and PDF extraction) | Python 3.12.10, Icarus Verilog 12.2022.06.11 at `C:\iverilog\bin`, yowasp-yosys 0.71, pypdf 7.1.1 |
| R5 | DONE | Choose the lattice scheme, parameter set and top-level interface with the engineer before RTL work (flagged ambiguity - four schemes in the PDF) | Engineer selected Falcon/FN-DSA, standards-compliant parameters, first block narrowed to the Falcon-512 verify core |
| R6 | DONE | Write synthesizable FPGA-friendly RTL following PART 2: headers, `_q`/`_c`, numbered sections, elaboration checks, `RTL_SIM`-guarded sim-only code | `rtl/falcon512_pkg.sv`, `rtl/falcon512_ntt.sv`, `rtl/falcon512_verify.sv`; `lint/lint.log` has `lint: clean (0 errors)` |
| R7 | DONE | Write a self-checking testbench with a reference model, error count, watchdog and `RESULT  = PASS` end-of-test line, and run it | `sim/tb_falcon512_verify.sv`; `sim/sim.log` reports eight runs with zero mismatches and `RESULT  = PASS` |
| R8 | DONE | Produce lint and synthesis evidence from real tool runs into `lint/` and `synth/` | `lint/lint.log` has `lint: clean (0 errors)`; `synth/synth_probe.log` has `synthesis successful (0 errors)` from Yosys 0.71 |
| R9 | DONE | Write the three PART 7 documents: design spec, test plan, verification report | `docs/falcon512_verify_design_spec.md`, `docs/falcon512_testplan.md`, `docs/falcon512_verification.md` |
| R10 | DONE | Run a mutation campaign against the final RTL/bench and record results in the verification report | M1-M5 all `KILLED`; raw mutation logs summarised in `design/falcon512_verify/docs/falcon512_verification.md` |
| R11 | DONE | Commit stable states with short, human-friendly commit messages | verified RTL, bench, evidence and three documents committed together after all gates passed |

## Suggested (not built without approval)

| ID | Status | Item | Why deferred |
|---|---|---|---|
| S1 | - | Full parameterised implementations of all four schemes | The PDF covers Kyber, FrodoKEM, Dilithium and Falcon; one block at a time is the manageable scope |
| S2 | - | Place-and-route / static timing sign-off | No open-source PnR/STA flow installed here; `TIMING` gate will stay grey and be reported honestly |
| S3 | - | CDC and formal-property sign-off | Single clock/reset expected and no CDC/FPV tool installed; gates stay grey unless needed |
