# verilator_lint.ps1 — Fast Verilator lint (no C++ link) on all RTL

$ErrorActionPreference = "Stop"
$Bash = "C:\msys64\usr\bin\bash.exe"

& $Bash -lc "export PATH=/ucrt64/bin:/usr/bin:/c/iverilog/bin:`$PATH && cd /c/Projects/GPU && verilator --lint-only -Wall -Wno-UNUSEDPARAM rtl/gpu_pkg.sv rtl/core/isa_pkg.sv rtl/core/instr_decode.sv rtl/core/vector_rom.sv rtl/core/warp_scheduler.sv rtl/core/shader_core.sv rtl/mac/mac_unit.sv rtl/mac/mac_array.sv tb/mac/mac_unit_tb.sv tb/mac/mac_array_tb.sv tb/core/shader_core_tb.sv"

if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Verilator lint: OK"
