# verilator_sim.ps1 — Verilator lint + Icarus SV simulation
#
# Usage:
#   .\scripts\verilator_sim.ps1 mac_unit
#   .\scripts\verilator_sim.ps1 mac_array
#   .\scripts\verilator_sim.ps1 all

param(
    [Parameter(Position = 0)]
    [ValidateSet("mac_unit", "mac_array", "shader_core", "systolic_gemm", "sram", "vau", "systolic_accel", "all")]
    [string]$Target = "all"
)

$ErrorActionPreference = "Stop"
$Shell = "C:\msys64\msys2_shell.cmd"
$Script = "/c/Projects/GPU/scripts/verilator_run.sh"

if (-not (Test-Path $Shell)) {
    Write-Host "MSYS2 not found. Run: .\scripts\setup_eda.ps1"
    exit 1
}

function Invoke-Sim {
    param([string]$Name)
    & $Shell -ucrt64 -defterm -no-start -here -c "bash $Script $Name"
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

if ($Target -eq "all") {
    Invoke-Sim "mac_unit"
    Invoke-Sim "mac_array"
    Invoke-Sim "shader_core"
    Invoke-Sim "systolic_gemm"
    Invoke-Sim "sram"
    Invoke-Sim "vau"
    Invoke-Sim "systolic_accel"
} else {
    Invoke-Sim $Target
}
