# run_all.ps1 — Full verification stack: pytest + Verilator + Yosys
#
# Usage: .\scripts\run_all.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host "=== Python golden model tests ==="
& python -m pytest verify/ -v
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== Verilator lint ==="
& "$PSScriptRoot\verilator_lint.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== Verilator simulation ==="
& "$PSScriptRoot\verilator_sim.ps1" all
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== Yosys synthesis ==="
& "$PSScriptRoot\yosys_synth.ps1"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "=== FULL STACK PASSED ==="
