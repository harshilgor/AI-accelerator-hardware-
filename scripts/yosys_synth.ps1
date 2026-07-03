# yosys_synth.ps1 — Run Yosys logic synthesis via MSYS2 bash
#
# Usage: .\scripts\yosys_synth.ps1

$ErrorActionPreference = "Stop"
$Bash = "C:\msys64\usr\bin\bash.exe"
$Root = Split-Path -Parent $PSScriptRoot

& $Bash -lc "export PATH=/usr/bin:/ucrt64/bin:`$PATH && cd /c/Projects/GPU && mkdir -p synth/yosys && yosys -s scripts/yosys_synth.ys"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Gate-level netlists:"
Write-Host "  synth/yosys/mac_unit_syn.v"
Write-Host "  synth/yosys/mac_array_syn.v"
