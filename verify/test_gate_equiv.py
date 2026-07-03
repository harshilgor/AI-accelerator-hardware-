"""Phase 4 gate-level checks: RTL/gate cosim and optional Yosys formal equivalence."""

from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASH = Path(r"C:\msys64\usr\bin\bash.exe")


def _bash(script: str, timeout: int | None = None) -> subprocess.CompletedProcess[str]:
    if not BASH.is_file():
        raise RuntimeError(f"MSYS2 bash not found at {BASH}")
    root_posix = "/" + str(ROOT).replace("\\", "/").replace(":", "", 1)
    env = os.environ.copy()
    env["PATH"] = "/ucrt64/bin:/usr/bin:/c/iverilog/bin:" + env.get("PATH", "")
    return subprocess.run(
        [str(BASH), "-lc", f"cd {root_posix} && {script}"],
        capture_output=True,
        text=True,
        timeout=timeout,
        check=False,
    )


def test_rtl_gate_cosim_rtl_golden() -> None:
    """RTL must match Python-style golden vectors; gate compared to RTL."""
    result = _bash("bash scripts/gate_sim.sh", timeout=120)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "PASS [single MAC 3*4]" in result.stdout
    assert "PASS [accumulate chain]" in result.stdout
    assert "PASS [clear]" in result.stdout
    assert "PASS [signed negative a]" in result.stdout
    assert "PASS [signed both negative]" in result.stdout


def test_rtl_gate_cosim_equivalence() -> None:
    """Gate netlist must match RTL on every check (Icarus + simlib)."""
    result = _bash("bash scripts/gate_sim.sh", timeout=120)
    out = result.stdout + result.stderr
    assert result.returncode == 0, out
    assert "RTL/GATE COSIM EQUIV PASSED" in out, out


def test_yosys_formal_equiv_mac_unit() -> None:
    """Full formal equivalence mac_unit RTL vs techmap (slow; skip unless RUN_FORMAL=1)."""
    if os.environ.get("RUN_FORMAL") != "1":
        import pytest

        pytest.skip("Set RUN_FORMAL=1 to run Yosys equiv_simple (~5-15 min)")

    log = ROOT / "synth" / "reports" / "equiv_mac_unit.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    result = _bash(
        f"yosys -s scripts/equiv_mac_unit.ys 2>&1 | tee {log.as_posix()}",
        timeout=1200,
    )
    text = log.read_text(encoding="utf-8", errors="replace") if log.is_file() else ""
    combined = text + result.stdout + result.stderr
    assert result.returncode == 0, combined[-4000:]
    assert re.search(r"Equivalence successfully proven|No unproven \$equiv cells", combined), (
        "Formal equiv did not report success; see synth/reports/equiv_mac_unit.log"
    )


if __name__ == "__main__":
    for name in (
        "test_rtl_gate_cosim_rtl_golden",
        "test_rtl_gate_cosim_equivalence",
    ):
        fn = getattr(sys.modules[__name__], name)
        fn()
        print(f"ok {name}")
