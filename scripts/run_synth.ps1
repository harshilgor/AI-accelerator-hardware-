# run_synth.ps1 — Run Vivado synthesis for Basys 3 (batch mode)
#
# Prerequisites:
#   1. Install Vivado WebPACK (free): https://www.xilinx.com/support/download.html
#   2. Digilent Basys 3 board (optional until programming)
#
# Usage: .\scripts\run_synth.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)

# Common Vivado install locations on Windows
$VivadoCandidates = @(
    "C:\Xilinx\Vivado\*\bin\vivado.bat",
    "C:\tools\Xilinx\Vivado\*\bin\vivado.bat",
    "$env:USERPROFILE\Xilinx\Vivado\*\bin\vivado.bat"
)

$Vivado = $null
foreach ($pattern in $VivadoCandidates) {
    $found = Get-Item $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($found) {
        $Vivado = $found.FullName
        break
    }
}

if (-not $Vivado) {
    $cmd = Get-Command vivado -ErrorAction SilentlyContinue
    if ($cmd) { $Vivado = $cmd.Source }
}

if (-not $Vivado) {
    Write-Host ""
    Write-Host "Vivado not found. Install Vivado WebPACK first:"
    Write-Host "  https://www.xilinx.com/support/download.html"
    Write-Host ""
    Write-Host "Select device family: Artix-7 (for Basys 3)"
    Write-Host "Edition: WebPACK (free)"
    Write-Host "Install size: ~30-35 GB"
    Write-Host ""
    Write-Host "After install, re-run: .\scripts\run_synth.ps1"
    exit 1
}

Write-Host "Using Vivado: $Vivado"
Write-Host "Building basys3_top for xc7a35tcpg236-1..."
Write-Host "(This can take 5-15 minutes on first run)"
Write-Host ""

Set-Location $Root
& $Vivado -mode batch -source scripts/vivado_build.tcl
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Expected on board: LEDs show 372 (0x0174) after releasing btnC reset"
