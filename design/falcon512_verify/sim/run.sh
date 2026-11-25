#!/bin/bash
# -------------------------------
# Author      : desktop-ifrf24e\najam
# Description : Compile and run the Falcon-512 verify self-checking bench.
# -------------------------------
# Usage
#   ./run.sh              compile and run, writing sim.log
#   ./run.sh -compile     compile only
#   ./run.sh -clean       remove generated files
# -------------------------------

set -o pipefail

cleaning_func () {
  rm -f my_sim_exe sim.log simulation.vcd
  echo "Generated simulation files cleaned."
}

mode="${1:-}"
if [[ "$mode" == "-clean" ]]; then
  cleaning_func
  exit 0
fi
if [[ "$mode" == "-h" || "$mode" == "--help" ]]; then
  echo "Usage: ./run.sh [-compile|-clean]"
  exit 0
fi

iverilog -s tb_falcon512_verify -g2012 -f f_list.f -o my_sim_exe tb_falcon512_verify.sv 2>&1 | tee sim.log
if [[ $? -ne 0 ]]; then exit 1; fi
if [[ "$mode" == "-compile" ]]; then exit 0; fi

vvp my_sim_exe 2>&1 | tee -a sim.log
rc=$?
rm -f my_sim_exe
exit $rc
