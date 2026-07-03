#!/usr/bin/env bash
# gate_sim.sh — Synthesize gate netlist and run RTL vs gate functional equivalence (Icarus)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="/ucrt64/bin:/usr/bin:${PATH:-}"
IVERILOG="${IVERILOG:-/c/iverilog/bin/iverilog}"
VVP="${VVP:-/c/iverilog/bin/vvp}"
SIMLIB="${YOSYS_SIMLIB:-/ucrt64/share/yosys/simlib.v}"

mkdir -p synth/yosys sim synth/reports

echo "=== Synthesizing mac_unit gate netlist ==="
yosys -q -p '
  read_verilog -sv rtl/mac/mac_unit.sv
  hierarchy -top mac_unit
  proc; opt; fsm; opt; memory; opt
  async2sync
  techmap; opt
  setundef -zero
  dffunmap
  rename -top mac_unit_gate
  write_verilog synth/yosys/mac_unit_gate_syn.v
'

echo "=== Compiling RTL vs gate cosim ==="
"$IVERILOG" -g2012 -o sim/mac_rtl_gate.vvp \
  "$SIMLIB" \
  rtl/mac/mac_unit.sv \
  synth/yosys/mac_unit_gate_syn.v \
  tb/mac/mac_unit_rtl_gate_tb.sv

echo "=== Running functional equivalence sim ==="
"$VVP" sim/mac_rtl_gate.vvp
