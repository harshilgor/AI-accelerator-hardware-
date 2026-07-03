# run_sim.ps1 — Icarus Verilog simulation (legacy / learning)
#
# Main simulator: .\scripts\verilator_sim.ps1
# Usage: .\scripts\run_sim.ps1 [mac_unit|mac_array]

param(
    [Parameter(Position = 0)]
    [ValidateSet("mac_unit", "mac_array")]
    [string]$Target = "mac_unit"
)

. "$PSScriptRoot\eda_env.ps1"

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

New-Item -ItemType Directory -Force -Path "$Root\sim" | Out-Null
Set-Location $Root

$Top = "${Target}_tb"
Write-Host "Compiling $Top (Icarus)..."
iverilog -g2012 -o "sim/$Top.vvp" rtl/gpu_pkg.sv "rtl/mac/$Target.sv" "tb/mac/$Top.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Running simulation..."
vvp "sim/$Top.vvp"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Waveform: sim/$Top.vcd"
Write-Host "Open: .\scripts\view_waves.ps1"
