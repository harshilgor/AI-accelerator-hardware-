# setup_eda.ps1 — One-time EDA toolchain setup (MSYS2 packages)
#
# Run once after: winget install MSYS2.MSYS2

$ErrorActionPreference = "Stop"
$Bash = "C:\msys64\usr\bin\bash.exe"

if (-not (Test-Path $Bash)) {
    Write-Host "Install MSYS2 first: winget install MSYS2.MSYS2"
    exit 1
}

Write-Host "Installing EDA packages (Verilator, Yosys, GTKWave, make, perl)..."
& $Bash -lc @'
pacman -S --noconfirm --needed \
    perl \
    mingw-w64-ucrt-x86_64-verilator \
    mingw-w64-ucrt-x86_64-yosys \
    mingw-w64-ucrt-x86_64-gtkwave \
    mingw-w64-ucrt-x86_64-make
'@

Write-Host ""
Write-Host "Optional: Icarus Verilog (learning / SV testbench sim)"
Write-Host "  winget install Icarus.Verilog"
Write-Host ""
Write-Host "Run full stack: .\scripts\run_all.ps1"
