# scripts/eda_env.ps1 — Add MSYS2 UCRT64 EDA tools to PATH (Verilator, Yosys, GTKWave)

$EdaBin = "C:\msys64\ucrt64\bin"
$IverilogBin = "C:\iverilog\bin"

if (Test-Path $EdaBin) {
    $env:Path = "$EdaBin;$env:Path"
}
if (Test-Path $IverilogBin) {
    $env:Path = "$IverilogBin;$env:Path"
}
