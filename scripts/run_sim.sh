#!/usr/bin/env bash
# run_sim.sh — Compile and simulate mac_unit with Icarus Verilog (Linux/macOS)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/sim"
cd "$ROOT"

echo "Compiling RTL + testbench..."
iverilog -g2012 -o sim/mac_unit_tb.vvp rtl/mac_unit.v tb/mac_unit_tb.v

echo "Running simulation..."
vvp sim/mac_unit_tb.vvp

echo ""
echo "Waveform written to sim/mac_unit_tb.vcd"
echo "Open with GTKWave: gtkwave sim/mac_unit_tb.vcd"
