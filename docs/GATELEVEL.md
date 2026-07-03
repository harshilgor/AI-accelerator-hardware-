# Gate-Level Equivalence — Phase 4

**Author:** Harshil Gor  
**Project:** TensorMesh-16  
**Status:** Phase 4 complete (formal + cosim methodology)

Phase 4 closes the loop between RTL simulation (Phases 1–2) and Yosys synthesis (Phase 3) by proving that the **synthesized netlist preserves RTL behavior**.

---

## 1. Goals

| Check | Tool | What it proves |
|-------|------|----------------|
| **Formal equivalence** | Yosys `equiv_opt` / `equiv_simple` | RTL ≡ techmap netlist (all states/outputs) |
| **RTL vs gate cosim** | Icarus + `simlib.v` | Same stimulus → same `acc` on RTL and gate |
| **RTL golden regression** | Existing `mac_unit_tb` | RTL still matches algorithmic golden |

Formal equivalence is the **signoff** check. Cosim is a fast regression that catches flow mistakes before a long formal run.

---

## 2. Blocks in scope

| Module | RTL | Formal script | Cosim TB |
|--------|-----|---------------|----------|
| `mac_unit` | `rtl/mac/mac_unit.sv` | `scripts/equiv_mac_unit_opt.ys` | `tb/mac/mac_unit_rtl_gate_tb.sv` |
| `mac_array` | `rtl/mac/mac_array.sv` | `scripts/equiv_mac_array.ys` | *(formal only in v1)* |

Larger blocks (`shader_core`, full systolic mesh) stay on RTL + Python golden verification until generate unrolling for synthesis.

---

## 3. Synthesis flow (gate netlist)

Gate netlists for cosim use the same transforms as formal **gate** side:

```text
read_verilog → hierarchy → proc → opt → fsm → memory → opt
→ async2sync          # sync reset model (formal + cosim)
→ techmap → opt
→ setundef -zero
→ dffunmap            # map $_DFF_* back to sim-friendly FFs (required for Icarus cosim)
→ write_verilog synth/yosys/mac_unit_gate_syn.v
```

`async2sync` matches the Yosys equivalence recipe and avoids async-reset mismatches between RTL sim and mapped flip-flops.

---

## 4. Running checks locally

### Quick cosim (~5 s)

```powershell
.\scripts\gate_equiv.ps1 -Quick
```

Or:

```bash
bash scripts/gate_sim.sh
```

This synthesizes `mac_unit_gate`, compiles RTL + gate + `tb/mac/mac_unit_rtl_gate_tb.sv` with Icarus and `simlib.v`, and checks:

1. RTL `acc` matches golden test vectors (same as `mac_unit_tb`).
2. Gate `acc` matches RTL at each sample point.

### Full formal equivalence (~10–15 min per block)

```powershell
.\scripts\gate_equiv.ps1
```

Or manually:

```bash
yosys -s scripts/equiv_mac_unit_opt.ys    # recommended (equiv_opt + induction)
yosys -s scripts/equiv_mac_array.ys       # equiv_simple
```

Logs: `synth/reports/equiv_mac_unit.log`, `synth/reports/equiv_mac_array.log`.

### Pytest integration

```bash
# Fast: RTL golden + RTL/gate cosim
python -m pytest verify/test_gate_equiv.py -q

# Slow: add Yosys equiv_simple (set env var)
set RUN_FORMAL=1
python -m pytest verify/test_gate_equiv.py -q
```

---

## 5. Methodology notes

### Why `equiv_opt -async2sync -undef -assert techmap`

- **async2sync** — Maps `always_ff @(posedge clk or negedge rst_n)` to sync reset so gold and gate use the same reset model.
- **-undef** — Models X/Z during induction; required after `techmap` leaves undriven carry bits.
- **techmap** — The optimization under test (generic gates in `techmap.v`).

`equiv_induct` inside `equiv_opt` proves sequential equivalence. Runtime scales with multiplier bit-blast (~10 min for `mac_unit` on a laptop).

### Icarus cosim and `dffunmap`

After `techmap`, Yosys emits `$_DFF_*` / `$_SDFF_*` cells from `simlib.v`. For multi-level MAC carry chains, Icarus can sample `acc` before combinational paths settle unless flip-flops are **dffunmapped** back to behavioral `always` registers. The cosim flow therefore ends with `dffunmap` before `write_verilog`.

Standalone gate-only TB (`tb/mac/mac_unit_gls_tb.sv`) is optional; the signoff cosim is RTL vs gate in `mac_unit_rtl_gate_tb.sv`.

### Signed INT16

RTL uses `logic signed` ports. Yosys preserves signed `$mul` / `$macc` through `techmap` (`A_SIGNED=1` in synthesis log). Formal equiv proves signed behavior is preserved; do not rely on unsigned wire declarations in the emitted `.v` file.

---

## 6. File map

```text
scripts/
  gate_sim.sh              # synth gate + Icarus cosim
  gate_equiv.ps1           # cosim + optional formal
  equiv_mac_unit.ys        # equiv_simple (full state)
  equiv_mac_unit_opt.ys    # equiv_opt techmap (recommended)
  equiv_mac_array.ys
tb/mac/
  mac_unit_rtl_gate_tb.sv  # RTL vs gate equivalence
  mac_unit_gls_tb.sv       # gate-only (informational)
verify/
  test_gate_equiv.py
synth/yosys/
  mac_unit_gate_syn.v      # generated (gitignored)
synth/reports/
  equiv_*.log              # generated (gitignored)
```

---

## 7. Results (representative)

| Check | mac_unit | Notes |
|-------|----------|-------|
| RTL golden (`mac_unit_tb`) | PASS | 2-cycle pipeline |
| RTL vs gate cosim | **PASS** | `async2sync` + `dffunmap` netlist |
| `equiv_opt` formal | Run locally | `scripts/equiv_mac_unit_opt.ys`, ~10–15 min |
| `equiv_simple` (mac_array) | Run locally | `scripts/equiv_mac_array.ys` |

Re-run after RTL changes:

```powershell
.\scripts\gate_equiv.ps1 -Quick   # every commit
.\scripts\gate_equiv.ps1          # before release / portfolio snapshot
```

---

## 8. Roadmap

| Item | Status |
|------|--------|
| mac_unit formal equiv | Scripts + docs |
| mac_array formal equiv | Script ready |
| mac_array cosim TB | Planned |
| `shader_core` equiv | Blocked on hierarchy size |
| CI: `test_gate_equiv.py` | Ready (`RUN_FORMAL=1` optional job) |

---

*TensorMesh-16 — Harshil Gor*
