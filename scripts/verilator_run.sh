#!/usr/bin/env bash
# verilator_run.sh — Verilator lint + Icarus simulation
set -euo pipefail

export MSYSTEM=UCRT64
export PATH="/ucrt64/bin:/usr/bin:/c/iverilog/bin:${PATH}"

TARGET="${1:?Usage: verilator_run.sh mac_unit|mac_array|shader_core|systolic_gemm|sram|vau|systolic_accel|all}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

mkdir -p sim

run_one() {
    local name="$1"
    local top="${name}_tb"
    echo ""
    echo "=== Verilator lint: $name ==="

    case "$name" in
        mac_unit)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND \
                rtl/gpu_pkg.sv rtl/mac/mac_unit.sv "tb/mac/${top}.sv"
            ;;
        mac_array)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND \
                rtl/gpu_pkg.sv rtl/mac/mac_array.sv "tb/mac/${top}.sv"
            ;;
        shader_core)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND \
                --top-module shader_core_tb \
                rtl/gpu_pkg.sv rtl/core/isa_pkg.sv \
                rtl/core/instr_decode.sv rtl/core/vector_rom.sv \
                rtl/core/warp_scheduler.sv rtl/core/shader_core.sv \
                rtl/mac/mac_array.sv "tb/core/${top}.sv"
            ;;
        systolic_gemm)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND \
                --top-module systolic_gemm_tb \
                rtl/gpu_pkg.sv rtl/systolic/pe.sv rtl/systolic/systolic_mesh.sv \
                rtl/systolic/systolic_gemm.sv "tb/systolic/${top}.sv"
            ;;
        sram)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-INITIALDLY \
                rtl/mem/sync_sram.sv "tb/mem/${top}.sv"
            ;;
        systolic_accel)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-INITIALDLY -Wno-PINCONNECTEMPTY \
                --top-module systolic_accel_tb \
                rtl/gpu_pkg.sv rtl/activ/act_pkg.sv rtl/activ/act_lut_rom.sv \
                rtl/activ/act_unit.sv rtl/activ/vau.sv \
                rtl/mem/sync_sram.sv rtl/mem/matrix_mem.sv \
                rtl/systolic/pe.sv rtl/systolic/systolic_mesh.sv rtl/systolic/systolic_gemm.sv \
                rtl/systolic/systolic_accel.sv "tb/systolic/${top}.sv"
            ;;
        vau)
            verilator --lint-only -Wall -Wno-UNUSEDPARAM -Wno-WIDTHTRUNC -Wno-UNUSEDSIGNAL -Wno-WIDTHEXPAND -Wno-INITIALDLY \
                --top-module vau_tb \
                rtl/gpu_pkg.sv rtl/activ/act_pkg.sv rtl/activ/act_lut_rom.sv \
                rtl/activ/act_unit.sv rtl/activ/vau.sv "tb/activ/${top}.sv"
            ;;
    esac

    echo ""
    echo "=== Icarus sim: $top ==="
    case "$name" in
        mac_unit)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/gpu_pkg.sv rtl/mac/mac_unit.sv "tb/mac/${top}.sv"
            ;;
        mac_array)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/gpu_pkg.sv rtl/mac/mac_array.sv "tb/mac/${top}.sv"
            ;;
        shader_core)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/gpu_pkg.sv rtl/core/isa_pkg.sv \
                rtl/core/instr_decode.sv rtl/core/vector_rom.sv \
                rtl/core/warp_scheduler.sv rtl/core/shader_core.sv \
                rtl/mac/mac_array.sv "tb/core/${top}.sv"
            ;;
        systolic_gemm)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/gpu_pkg.sv rtl/systolic/pe.sv rtl/systolic/systolic_mesh.sv \
                rtl/systolic/systolic_gemm.sv "tb/systolic/${top}.sv"
            ;;
        sram)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/mem/sync_sram.sv "tb/mem/${top}.sv"
            ;;
        systolic_accel)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/gpu_pkg.sv rtl/activ/act_pkg.sv rtl/activ/act_lut_rom.sv \
                rtl/activ/act_unit.sv rtl/activ/vau.sv \
                rtl/mem/sync_sram.sv rtl/mem/matrix_mem.sv \
                rtl/systolic/pe.sv rtl/systolic/systolic_mesh.sv rtl/systolic/systolic_gemm.sv \
                rtl/systolic/systolic_accel.sv "tb/systolic/${top}.sv"
            ;;
        vau)
            iverilog -g2012 -o "sim/${top}.vvp" \
                rtl/gpu_pkg.sv rtl/activ/act_pkg.sv rtl/activ/act_lut_rom.sv \
                rtl/activ/act_unit.sv rtl/activ/vau.sv "tb/activ/${top}.sv"
            ;;
    esac
    vvp "sim/${top}.vvp"
    echo "VCD: sim/${top}.vcd"
}

case "$TARGET" in
    all)
        run_one mac_unit
        run_one mac_array
        run_one shader_core
        run_one systolic_gemm
        run_one sram
        run_one vau
        run_one systolic_accel
        ;;
    *)
        run_one "$TARGET"
        ;;
esac
