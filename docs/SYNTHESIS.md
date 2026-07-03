# TensorMesh-16 — Synthesis Report

**Author:** [Harshil Gor](https://github.com/harshilgor)  
**Repository:** [github.com/harshilgor/AI-accelerator-hardware-](https://github.com/harshilgor/AI-accelerator-hardware-)  
**Last updated:** July 2026  
**Status:** Phase 3 — Yosys logic synthesis complete; OpenROAD / Sky130 physical flow optional

---

## 1. Overview

This document reports **logic synthesis** results for TensorMesh-16 using **Yosys 0.66** with generic `techmap` (AND/OR/XOR/MUX/DFF gate model). These are **pre-PD (pre-place-and-route)** statistics suitable for architecture-level area/timing reasoning—not signoff-quality Sky130 µm² without OpenROAD mapping.

**Regenerate locally:**

```powershell
.\scripts\synth_report.ps1
```

Full log: `synth/reports/yosys_latest.log`

---

## 2. Toolchain

| Tool | Version | Role |
|------|---------|------|
| Yosys | 0.66 (MSYS2 ucrt64) | RTL → gate-level netlist + `stat` |
| Generic `techmap` | built-in | Maps RTL to `$_AND_`, `$_MUX_`, `$_DFF_*`, etc. |
| OpenROAD | *not installed* | Optional Sky130 place & route (see §6) |

**Netlists (gitignored):** `synth/yosys/*_syn.v`

---

## 3. Synthesized blocks

### 3.1 Cell counts (generic technology mapping)

| Top module | Cells | DFF / DFFE | MUX | Notes |
|------------|------:|----------:|----:|-------|
| `mac_unit` | **2,252** | 67 | 64 | 16×16 pipelined MAC, 32-bit acc |
| `mac_array` | **7,494** | 165 | 68 | 4× `mac_unit` + sum tree |
| `pe` | **5,075** | 99 | 192 | Systolic PE: 48-bit acc, WS `weight_reg` |
| `sync_sram` | **8,768** | 4,096 | 4,104 | 256×16 — memory inferred as registers |
| `shader_core` | **7,866** | 257 | 164 | Hierarchy total incl. submodules |

### 3.2 Submodule breakdown (`shader_core`)

| Submodule | Cells |
|-----------|------:|
| `mac_array` | 7,494 |
| `warp_scheduler` | 291 |
| `vector_rom` | 9 |
| `shader_core` glue | 72 |

### 3.3 Not yet synthesized

| Block | Reason |
|-------|--------|
| `systolic_gemm` / `systolic_mesh` | 256-PE `generate` loop — needs unrolling or hierarchical synth |
| `systolic_accel` | Depends on full mesh + controller |
| `act_unit` / `vau` | `import act_pkg::*` — Yosys frontend limitation; wrapper planned |
| `matrix_mem` | Multi-bank hierarchy; synthesize after SRAM mapping strategy chosen |

---

## 4. Area extrapolation (architecture estimates)

### 4.1 Systolic mesh (16×16 = 256 PEs)

Using measured `pe` cell count:

```
Mesh_logic ≈ 256 × 5,075 = 1,299,200 generic cells
```

| Component | Estimate (generic cells) | Method |
|-----------|-------------------------:|--------|
| 16×16 PE array | **~1.30M** | 256 × `pe` stat |
| `systolic_gemm` controller | ~5K–20K (guess) | Skew FSM + muxes (not synthesized) |
| Inter-PE routing overhead | +10–15% | Mesh wiring factor |
| **Total compute array** | **~1.4–1.5M** | Order-of-magnitude |

### 4.2 On-chip memory (`matrix_mem`)

Banks A/B: 256 × 16-bit; banks C: 256 × 48-bit; bank D: 256 × 16-bit.

| Bank | Depth × width | Register-style bits (Yosys model) |
|------|---------------|----------------------------------|
| A | 256 × 16 | 4,096 |
| B | 256 × 16 | 4,096 |
| C | 256 × 48 | 12,288 |
| D | 256 × 16 | 4,096 |
| **Total** | | **24,576 flip-flop bits** |

**Production note:** A real tapeout would infer **SRAM macros** (Sky130 HD SRAM or compiled memory), reducing cell count by ~10× vs register file inference.

### 4.3 Shader core vs systolic

| Engine | Synthesized cells | Role |
|--------|------------------:|------|
| Shader core | ~7,866 | Lightweight vector / warp path |
| Single PE | ~5,075 | One dot in the mesh |
| Full mesh | ~1.3M | Dominates die area |

The systolic array is the **area driver**; the shader core is architecturally complementary but physically small.

---

## 5. Timing estimates (pre-STA)

Without Sky130 Liberty + OpenROAD STA, these are **architecture-level** bounds:

| Block | Critical path (qualitative) | Indicative Fmax |
|-------|----------------------------|-----------------|
| `mac_unit` | 16×16 multiply → 32-bit acc pipeline (2 stages) | 100–300 MHz (FPGA/130nm class) |
| `pe` | Combinational mult + 48-bit acc feedback | 50–200 MHz |
| `shader_core` | Scheduler + MAC array | Similar to `mac_array` |
| Full mesh | Longest row/column propagate + PE mult | **PE-limited** |

**OS mode** completes 16×16 GEMM in ~63 cycles; at **100 MHz** → ~630 ns per GEMM.  
**WS mode** ~1009 cycles → ~10.1 µs per GEMM at 100 MHz.

Throughput at 100 MHz (OS): ~**6.5 GOPS** INT16 (see [ARCHITECTURE.md](ARCHITECTURE.md) §6.3).

---

## 6. OpenROAD + SkyWater 130nm (optional next step)

OpenROAD was **not available** on the development host. To obtain real **µm² area** and **post-PD Fmax**:

1. Install [OpenROAD-flow-scripts (ORFS)](https://openroad-flow-scripts.readthedocs.io/) on Linux/WSL  
2. Install **SkyWater 130nm HD** PDK (open source via Google/efabless)  
3. Run placeholder script (checks for `openroad`):

```bash
bash scripts/openroad/run_sky130.sh mac_unit
```

4. Start with small blocks: `mac_unit` → `pe` → `mac_array`  
5. Copy ORFS reports (`report_area.rpt`, `report_timing.rpt`) into `synth/openroad/<block>/`

**What you need to provide:** Linux or WSL environment with ORFS installed (~20 GB disk). I can wire a full ORFS block config once that environment exists.

---

## 7. Methodology notes

### 7.1 Generic vs PDK mapping

Yosys `techmap` without `synth_sky130` produces **technology-independent** gate counts. Absolute die area requires:

```
RTL → Yosys → Liberty (sky130hd) → OpenROAD P&R → GDSII
```

### 7.2 SRAM inference

`sync_sram` synthesizes to **4096 `$_DFFE_PP_` cells** for 256×16 storage. Production flows should use:

- FPGA: `(* ram_style = "block" *)` or vendor BRAM inference
- ASIC: memory compiler / hard macro

### 7.3 PE package import fix

`pe.sv` uses a local `MODE_WEIGHT_STATIONARY` constant instead of `import gpu_pkg::*` so Yosys can synthesize the PE standalone. Simulation behavior is unchanged (`2'b01` matches `gpu_pkg`).

---

## 8. Reproducibility

```powershell
# Full synthesis + log
.\scripts\synth_report.ps1

# Legacy entry point (subset, no log file)
.\scripts\yosys_synth.ps1

# Full verify + synth stack
.\scripts\run_all.ps1
```

**Last measured run:** Yosys 0.66, Windows MSYS2 ucrt64, July 2026 — cell counts in §3.1.

---

## 9. Roadmap

| Phase | Goal | Status |
|-------|------|--------|
| 1 | Architecture spec | Done — [ARCHITECTURE.md](ARCHITECTURE.md) |
| 2 | Randomized verification | Done — [VERIFICATION.md](VERIFICATION.md) |
| 3 | Yosys synthesis + area/timing report | **Done** (this document) |
| 3b | OpenROAD Sky130 physical synthesis | Optional — needs ORFS install |
| 4 | Gate-level equivalence | Done — [docs/GATELEVEL.md](GATELEVEL.md) |
| 5 | Technical write-up | Done — [docs/WRITEUP.md](WRITEUP.md) |

---

## 10. What we need from you (optional)

| Item | Why |
|------|-----|
| **WSL/Linux + ORFS** | Real Sky130 µm² and MHz from place & route |
| **Push to GitHub** | Share synthesis docs on [your repo](https://github.com/harshilgor/AI-accelerator-hardware-) |
| **FPGA board (later)** | Validate Fmax on real hardware (Track A) |

Nothing else is required for Phase 3 as documented.

---

*TensorMesh-16 — Harshil Gor*
