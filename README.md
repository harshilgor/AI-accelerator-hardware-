# TensorMesh-16

**A configurable INT16 AI accelerator — systolic GEMM, fused activations, and warp-scheduled vector math**

**Author:** [Harshil Gor](https://github.com/harshilgor) · [Repository](https://github.com/harshilgor/AI-accelerator-hardware-)

TensorMesh-16 is a research-grade tensor processing unit (TPU-class) implemented in SystemVerilog. It targets the dominant operation in neural-network inference: **matrix multiply followed by nonlinear activation**, with runtime-selectable **output-stationary** and **weight-stationary** systolic dataflows—the same architectural knob found in production AI accelerators.

The project is built for **computer architecture engineering**: clean RTL hierarchy, Python golden-model co-verification, and a path toward synthesis signoff without requiring silicon or FPGA hardware.

---

## Highlights

| Capability | Detail |
|------------|--------|
| **Systolic GEMM** | 16×16 mesh, 256 processing elements, 48-bit accumulators |
| **Dual dataflow** | Output-stationary (fast) and weight-stationary (weight-reuse) modes |
| **Fused activation** | ReLU, GeLU, SiLU via pipelined VAU + LUT interpolation |
| **On-chip memory** | 4-bank SRAM (A, B, raw C, activated D) |
| **Shader core** | Warp-scheduled dot-product engine (SIMT-style, 2 warps) |
| **Verification** | Cycle-accurate Python models + pytest + Verilator + Icarus sim |
| **Synthesis** | Yosys flow for MAC, shader core, and selected blocks |

**Peak throughput (OS mode, 100 MHz):** ~6.5 GOPS INT16 for 16×16 GEMM

---

## Architecture

```
Host Load/Store
      │
      ▼
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│  matrix_mem │────►│  systolic_gemm   │────►│     VAU     │──► Bank D
│  A │ B │ C │ D  │  16×16 OS / WS   │     │ ReLU/GeLU/  │
└─────────────┘     └──────────────────┘     │    SiLU     │
                              │               └─────────────┘
                              └──► Bank C (raw GEMM output)

shader_core (standalone) — warp scheduler + MAC array for vector dot products
```

**Full specification:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)  
**Verification report:** [docs/VERIFICATION.md](docs/VERIFICATION.md)

---

## Repository layout

```
rtl/
  mac/           MAC unit and 4-lane MAC array
  core/          Shader core (ISA, warp scheduler, decode)
  systolic/      PE, mesh, GEMM controller, systolic_accel top
  activ/         Vector Activation Unit (VAU)
  mem/           SRAM banks and matrix memory subsystem
  top/           FPGA demo (Basys 3 — mac_array)
  gpu_pkg.sv     Shared parameters and dataflow modes

verify/          Python golden models and pytest suite
tb/              SystemVerilog testbenches
scripts/         Simulation, lint, synthesis, EDA setup
docs/            Architecture specification
constraints/     FPGA pin constraints (Basys 3)
```

---

## Quick start

### Prerequisites

- Python 3.10+
- [MSYS2](https://www.msys2.org/) with Verilator and Icarus Verilog (see `scripts/setup_eda.ps1`)
- Yosys (optional, for synthesis)

### Run the full verification stack

```powershell
.\scripts\run_all.ps1
```

This runs, in order:

1. **pytest** — golden model tests (`verify/`)
2. **Verilator lint** — RTL static checks
3. **Simulation** — mac_unit, mac_array, shader_core, systolic_gemm, sram, vau, systolic_accel
4. **Yosys synthesis** — gate-level netlists for selected blocks

### Run tests only

```powershell
python -m pytest verify/ -v
```

### Run a single simulation target

```powershell
.\scripts\verilator_sim.ps1 systolic_gemm
```

---

## Programming model (systolic_accel)

1. Host writes matrix **A** → bank A, matrix **B** → bank B
2. Assert `start`, set `dataflow_mode` (OS or WS) and `act_mode` (ReLU / GeLU / SiLU)
3. Poll `done`
4. Read activated results from bank **D**

Internal pipeline: `LOAD_A → LOAD_B → GEMM → STORE_C → ACTIVATE → FINISH`

See [docs/ARCHITECTURE.md §5](docs/ARCHITECTURE.md#5-programming-model-and-operation-sequence) for signal definitions and FSM detail.

---

## Dataflow modes

| Mode | Value | Behavior | Best for |
|------|-------|----------|----------|
| **Output-stationary** | `2'b00` | Single-pass skewed A/B stream; accumulators stay in PEs | Dense layers, minimum latency |
| **Weight-stationary** | `2'b01` | K-step loop: preload B[k][:], stream A[:][k] | Convolutional layers, weight reuse |

Controlled via `dataflow_mode` on `systolic_gemm` and `systolic_accel` (defined in `gpu_pkg.sv`).

---

## Verification philosophy

Every major RTL block has a **Python golden model** that mirrors hardware timing or semantics:

| Block | Golden model | Tests |
|-------|--------------|-------|
| MAC unit / array | `verify/golden_mac.py`, `golden_mac_array.py` | `test_mac.py`, `test_mac_array.py` |
| Shader core | `verify/golden_shader_core.py` | `test_shader_core.py` |
| Systolic GEMM | `verify/golden_systolic.py` | `test_systolic.py` (OS + WS) |
| Activation | `verify/golden_activation.py` | `test_activation.py` |

Regression is a single command: `.\scripts\run_all.ps1`

---

## Roadmap

| Phase | Goal | Status |
|-------|------|--------|
| 1 | Architecture specification | Done — [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) |
| 2 | Large-scale randomized verification | Done — [docs/VERIFICATION.md](docs/VERIFICATION.md) |
| 3 | OpenROAD synthesis + area/timing (SkyWater 130nm) | Planned |
| 4 | Gate-level equivalence | Planned |
| 5 | Technical write-up (OS vs WS dataflow) | Planned |

---

## Key parameters

```systemverilog
// rtl/gpu_pkg.sv
SYSTOLIC_SIZE   = 16        // 16×16 PE mesh
SYSTOLIC_WIDTH  = 16        // INT16 operands
SYSTOLIC_ACC_W  = 48        // GEMM accumulator
NUM_WARPS       = 2         // Shader core warps
WARP_SIZE       = 32        // Logical threads per warp
VAU_LATENCY     = 3         // Activation pipeline depth
```

---

## References

- Jouppi et al., *"In-Datacenter Performance Analysis of a Tensor Processing Unit"* (ISCA 2017)
- Kung & Leiserson, *"Systolic Arrays (for VLSI)"* (1979)
- Hennessy & Patterson, *Computer Architecture: A Quantitative Approach*

---

## License

All rights reserved — Harshil Gor. Contact for usage terms.
