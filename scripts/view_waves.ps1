# view_waves.ps1 — Open simulation waveform in GTKWave
#
# Usage:
#   .\scripts\view_waves.ps1
#   .\scripts\view_waves.ps1 -Vcd sim/mac_array_tb.vcd

param(
    [string]$Vcd = "sim/mac_unit_tb.vcd"
)

$ErrorActionPreference = "Stop"
. "$PSScriptRoot\eda_env.ps1"

$Root = Split-Path -Parent $PSScriptRoot
$VcdPath = Join-Path $Root $Vcd
$Gtkwave = "C:\msys64\ucrt64\bin\gtkwave.exe"

if (-not (Test-Path $VcdPath)) {
    Write-Host "No waveform found at $VcdPath"
    Write-Host "Run simulation first:"
    Write-Host "  .\scripts\verilator_sim.ps1"
    exit 1
}

if (-not (Test-Path $Gtkwave)) {
    Write-Host "GTKWave not found. Install via MSYS2:"
    Write-Host '  C:\msys64\usr\bin\bash.exe -lc "pacman -S --noconfirm mingw-w64-ucrt-x86_64-gtkwave"'
    exit 1
}

Write-Host "Opening $VcdPath"
Start-Process -FilePath $Gtkwave -ArgumentList $VcdPath
