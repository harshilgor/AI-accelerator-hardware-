# gate_equiv.ps1 — Yosys formal equivalence (RTL vs techmap netlist)
# Usage: .\scripts\gate_equiv.ps1 [-Quick]
#   -Quick  Run RTL/gate cosim only (seconds). Default also runs Yosys equiv_simple.

param(
    [switch]$Quick
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$bash = "C:\msys64\usr\bin\bash.exe"
if (-not (Test-Path $bash)) {
    Write-Error "MSYS2 bash not found at $bash"
}

New-Item -ItemType Directory -Force -Path synth/reports | Out-Null

Write-Host "=== RTL vs gate functional cosim (Icarus) ==="
& $bash -lc "export PATH=/ucrt64/bin:/usr/bin:/c/iverilog/bin:`$PATH && cd /c/Projects/GPU && bash scripts/gate_sim.sh"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

if ($Quick) {
    Write-Host "=== GATE EQUIV QUICK PASSED (cosim only) ==="
    exit 0
}

Write-Host ""
Write-Host "=== Yosys formal equiv: mac_unit (may take 5-15 min) ==="
$logUnit = "synth/reports/equiv_mac_unit.log"
& $bash -lc "export PATH=/ucrt64/bin:/usr/bin:`$PATH && cd /c/Projects/GPU && yosys -s scripts/equiv_mac_unit_opt.ys 2>&1 | tee $logUnit"
if ($LASTEXITCODE -ne 0) {
    Write-Host "mac_unit formal equiv did not complete successfully. See $logUnit"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== Yosys formal equiv: mac_array ==="
$logArray = "synth/reports/equiv_mac_array.log"
& $bash -lc "export PATH=/ucrt64/bin:/usr/bin:`$PATH && cd /c/Projects/GPU && yosys -s scripts/equiv_mac_array.ys 2>&1 | tee $logArray"
if ($LASTEXITCODE -ne 0) {
    Write-Host "mac_array formal equiv did not complete successfully. See $logArray"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "=== GATE EQUIV FULL PASSED ==="
