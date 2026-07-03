# synth_report.ps1 — Run Yosys synthesis and save a full statistics log
#
# Usage: .\scripts\synth_report.ps1

$ErrorActionPreference = "Stop"
$Bash = "C:\msys64\usr\bin\bash.exe"
$Root = Split-Path -Parent $PSScriptRoot
$ReportDir = Join-Path $Root "synth\reports"
$LogFile = Join-Path $ReportDir "yosys_latest.log"

if (-not (Test-Path $Bash)) {
    Write-Host "MSYS2 not found. Run: .\scripts\setup_eda.ps1"
    exit 1
}

New-Item -ItemType Directory -Force -Path (Join-Path $Root "synth\yosys") | Out-Null
New-Item -ItemType Directory -Force -Path $ReportDir | Out-Null

Write-Host "=== Yosys synthesis + statistics ==="
Write-Host "Log: $LogFile"
Write-Host ""

& $Bash -lc "export PATH=/usr/bin:/ucrt64/bin:`$PATH && cd /c/Projects/GPU && yosys -s scripts/yosys_synth.ys 2>&1 | tee synth/reports/yosys_latest.log"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Gate-level netlists (gitignored):"
Write-Host "  synth/yosys/mac_unit_syn.v"
Write-Host "  synth/yosys/mac_array_syn.v"
Write-Host "  synth/yosys/pe_syn.v"
Write-Host "  synth/yosys/sync_sram_syn.v"
Write-Host "  synth/yosys/shader_core_syn.v"
Write-Host ""
Write-Host "See docs/SYNTHESIS.md for interpreted results."
