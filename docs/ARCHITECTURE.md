# TensorMesh-16 — Architecture Specification

**Author:** [Harshil Gor](https://github.com/harshilgor)  
**Repository:** [github.com/harshilgor/AI-accelerator-hardware-](https://github.com/harshilgor/AI-accelerator-hardware-)  
**Version:** 0.1  
**Date:** July 2026  
**Status:** Research-grade AI accelerator — simulation-verified RTL

---

## 1. Executive Summary

This document describes the architecture of a **configurable AI accelerator** implemented in SystemVerilog. The design combines two compute paradigms found in modern GPUs and tensor processors:

1. **Shader-style vector core** — warp-scheduled dot products via a parallel MAC array
2. **Systolic matrix engine** — 16×16 mesh for general matrix multiply (GEMM), with runtime-selectable **output-stationary (OS)** and **weight-stationary (WS)** dataflows

A post-GEMM **Vector Activation Unit (VAU)** applies ReLU, GeLU, or SiLU to results stored in on-chip SRAM.

TensorMesh-16 is a **research-grade INT16 tensor accelerator** designed around the same architectural principles as production AI hardware (Google TPU, NVIDIA tensor cores): systolic GEMM, configurable dataflow, on-chip memory banking, and fused activation. The design is implemented in synthesizable SystemVerilog with cycle-accurate golden models and a full simulation/synthesis flow.

It is scoped for architecture research and portfolio demonstration—not a shipping commercial chip—but the block hierarchy, verification discipline, and dataflow configurability mirror what industry tensor processors optimize for at scale.

**Key parameters:**

| Parameter | Value |
|-----------|-------|
| Systolic array size | 16 × 16 (256 PEs) |
| Operand width | 16-bit signed |
| Accumulator width | 48-bit |
| Warps (shader core) | 2 × 32 logical threads |
| MAC lanes (shader) | 4 |
| On-chip memory banks | 4 (A, B, C, D) |
| Activation modes | ReLU, GeLU, SiLU |

---

## 2. Goals and Target Workloads

### 2.1 Design Goals

| Goal | Rationale |
|------|-----------|
| Demonstrate systolic GEMM at modest scale | Core operation in CNNs and LLMs |
| Support multiple dataflow patterns | Architecture trade-off study (OS vs WS) |
| Integrate activation in hardware | Reflect real inference pipelines (matmul → nonlinear) |
| Include a minimal shader core | Bridge GPU programming model and dedicated accelerators |
| Maintain verifiable RTL | Golden models + testbenches for architecture credibility |

### 2.2 Target Workloads

**Primary:** Fixed-size **16×16 signed integer matrix multiply** with optional element-wise activation:

```
D = activation(C)    where    C = A × B
```

**Secondary:** **8-element dot products** via the shader core (two warps, chunked into 4-lane MAC operations).

### 2.3 Non-Goals (v1)

- General-purpose GPU (graphics, arbitrary kernels)
- Dynamic batching, multi-chip scaling
- Floating-point (FP16/BF32) — fixed-point only in v1
- Production host interface (PCIe/DMA) — host port is a simple memory-mapped load/store

---

## 3. System Overview

### 3.1 Top-Level Block Diagram

```
                    ┌─────────────────────────────────────────────────────┐
                    │              systolic_accel (top pipeline)           │
                    │                                                      │
   Host             │   ┌──────────┐    ┌─────────────┐    ┌──────────┐   │
   Load/Store ──────┼──►│ matrix_mem│───►│systolic_gemm│───►│   VAU    │───┼──► Bank D
   (bank, addr)     │   │ A│B│C│D  │    │ 16×16 mesh  │    │ ReLU/    │   │
                    │   └──────────┘    │ OS / WS     │    │ GeLU/    │   │
                    │        ▲          └─────────────┘    │ SiLU     │   │
                    │        │                │             └──────────┘   │
                    │        └────────────────┘ (store C)         ▲        │
                    │                                              │        │
                    │   start, dataflow_mode, act_mode, done, busy          │
                    └─────────────────────────────────────────────────────┘

   Separate block (not integrated into systolic_accel):

                    ┌─────────────────────────────────────────────────────┐
                    │                   shader_core                        │
                    │   warp_scheduler ──► instr_decode ──► mac_array      │
                    │        │                              ▲              │
                    │        └──── vector_rom (operands) ───┘              │
                    └─────────────────────────────────────────────────────┘
```

### 3.2 Major Components

| Block | Role | RTL location |
|-------|------|--------------|
| `mac_unit` | Single pipelined multiply-accumulate | `rtl/mac/` |
| `mac_array` | 4 parallel MAC lanes (dot-product chunks) | `rtl/mac/` |
| `shader_core` | Warp-scheduled vector dot products | `rtl/core/` |
| `pe` | Systolic processing element | `rtl/systolic/` |
| `systolic_mesh` | 16×16 PE grid | `rtl/systolic/` |
| `systolic_gemm` | Skewed-input GEMM controller | `rtl/systolic/` |
| `matrix_mem` | 4-bank SRAM subsystem | `rtl/mem/` |
| `vau` / `act_unit` | Pipelined activation | `rtl/activ/` |
| `systolic_accel` | Full inference pipeline orchestrator | `rtl/systolic/` |

---

## 4. Component Descriptions

### 4.1 MAC Unit and MAC Array

**`mac_unit`** — 2-stage pipelined signed MAC:

- Inputs: `a`, `b` (16-bit), `valid`, `clear`
- Output: `acc` (32-bit), `acc_valid`
- On `clear`, accumulator resets; on `valid`, `acc += a × b`

**`mac_array`** — 4 parallel `mac_unit` instances with a combinational sum tree:

- Computes chunked dot products: 8 elements in 2 chunks of 4
- Used by the shader core for warp-level vector math

**Design decision:** 4 lanes balance parallelism and routing complexity for a teaching-scale shader core.

### 4.2 Shader Core

A minimal **SIMT-style** execution unit:

| Concept | Implementation |
|---------|----------------|
| Warps | 2 (`NUM_WARPS = 2`) |
| Logical threads | 32 per warp (`WARP_SIZE = 32`) — architectural, not per-thread hardware |
| ISA | 4 opcodes: `NOP`, `CLEAR`, `MAC`, `HALT` |
| Kernel | Hardcoded in `warp_scheduler`: CLEAR → MAC(chunk0) → MAC(chunk1) → HALT |
| Operands | `vector_rom` per warp |
| Execution | Warps share one `mac_array`; round-robin scheduling |

**Programming model (v1):** Assert `start`; each warp runs a fixed dot-product kernel; results appear in `warp_acc_0` and `warp_acc_1` on HALT.

**Limitation:** No load/store, branches, or dynamic instruction fetch — intentional for scope control.

### 4.3 Systolic Matrix Engine

#### 4.3.1 Processing Element (`pe`)

Each PE contains:

- Horizontal **A** datapath (flows right)
- Vertical **B** datapath (flows down)
- Local **accumulator** (48-bit)
- **`weight_reg`** (WS mode) — captures stationary weight during preload

#### 4.3.2 Mesh Topology (`systolic_mesh`)

- 16×16 array of PEs (256 total)
- Left edge: A injection per row
- Top edge: B injection per column
- Each `PE(i,j)` output `accum` holds partial or final sum for `C[i][j]`

#### 4.3.3 GEMM Controller (`systolic_gemm`)

Computes **C = A × B** for 16×16 matrices.

**Output-Stationary (OS) mode** (`MODE_OUTPUT_STATIONARY = 0`):

- Single pass: A and B stream with skewed injection schedule
- `A[i][k]` enters row `i` at cycle `i + k`
- `B[k][j]` enters column `j` at cycle `j + k`
- `PE(i,j)` performs MAC at cycle `i + j + k` for each `k`
- Run length: `3×N − 1` cycles (N = 16 → 47 cycles) + drain

**Weight-Stationary (WS) mode** (`MODE_WEIGHT_STATIONARY = 1`):

- **K-step outer loop** (k = 0 … N−1):
  1. **Preload:** Stream row `B[k][:]`, lock into each PE's `weight_reg`
  2. **Run:** Stream column `A[:][k]`, multiply by stationary weight, accumulate
- Accumulators are **not** cleared between k iterations
- Per-slice length: `2×N − 2` cycles (preload and run each)

### 4.4 Memory Subsystem (`matrix_mem`)

Four independent SRAM banks:

| Bank | ID | Content | Width | Size (16×16) |
|------|-----|---------|-------|--------------|
| A | 0 | Input matrix A | 16-bit | 256 elements |
| B | 1 | Input matrix B | 16-bit | 256 elements |
| C | 2 | Raw GEMM output | 48-bit | 256 elements |
| D | 3 | Post-activation output | 16-bit | 256 elements |

**Ports:**

- **Host port:** Single-transaction read/write (load matrices from host)
- **Accelerator port:** Used by `systolic_accel` FSM to load A/B, store C, feed VAU
- **Split VAU port:** Read bank C while writing bank D in the same cycle

### 4.5 Vector Activation Unit (VAU)

- **Latency:** 3 cycles (pipelined)
- **Modes:** ReLU (`0`), GeLU (`1`), SiLU (`2`)
- **Method:** Piecewise-linear LUT with linear interpolation (`act_lut_rom`)
- **Input:** 48-bit accumulator from bank C
- **Output:** 16-bit quantized result to bank D

---

## 5. Programming Model and Operation Sequence

### 5.1 Systolic Accelerator Pipeline

Host software (or testbench) sequence:

```
1. Write matrix A → bank A (256 host writes)
2. Write matrix B → bank B (256 host writes)
3. Assert start = 1, set dataflow_mode and act_mode
4. Poll until done = 1
5. Read results from bank D (or inspect bank C for raw GEMM)
```

**Internal FSM (`systolic_accel`):**

```
IDLE → LOAD_A → LOAD_B → RUN (GEMM) → STORE_C → ACTIVATE → FINISH
```

### 5.2 Control Signals

| Signal | Width | Description |
|--------|-------|-------------|
| `start` | 1 | Begin operation (latched on rising edge) |
| `dataflow_mode` | 2 | `00` = OS, `01` = WS |
| `act_mode` | 2 | `00` = ReLU, `01` = GeLU, `10` = SiLU |
| `busy` | 1 | High while pipeline is active |
| `done` | 1 | High when FINISH state reached |

### 5.3 Shader Core Usage

```
1. Assert start = 1
2. Wait until done = 1
3. Read warp_acc_0, warp_acc_1
```

---

## 6. Performance Analysis

### 6.1 OS Mode Cycle Count (N = 16)

| Phase | Cycles |
|-------|--------|
| Run | 47 (`3N − 1`) |
| Drain | ~16 |
| **Total GEMM** | **~63** |

### 6.2 WS Mode Cycle Count (N = 16)

| Phase | Cycles per k | × N iterations |
|-------|--------------|----------------|
| Preload | 31 (`2N − 2` + 1 tick) | × 16 |
| Run | 31 (`2N − 2` + 1 tick) | × 16 |
| **Subtotal** | 62 per k | × 16 = 992 |
| Drain | ~17 | |
| **Total GEMM** | **~1009** |

WS mode takes more cycles than OS but reduces B-matrix streaming during the compute phase — weights are preloaded into PE registers once per k-slice.

### 6.3 Throughput Estimate (OS, 100 MHz)

- One 16×16 GEMM ≈ 63 cycles
- MAC operations per GEMM: N³ = 4,096
- Effective throughput ≈ 4,096 / 63 ≈ **65 MACs/cycle**
- At 100 MHz: ≈ **6.5 GOPS** (INT16 multiply-adds)

### 6.4 OS vs WS Trade-off Summary

| Aspect | OS | WS |
|--------|----|----|
| B-matrix bandwidth during compute | High (re-streamed each k) | Low (preloaded once per k) |
| Control complexity | Lower | Higher (K-step FSM) |
| Cycle count (16×16) | ~63 | ~1009 |
| Best for | Dense layers, one-shot GEMM | Conv layers, weight reuse |

---

## 7. Area and Power Considerations (High-Level)

### 7.1 Area Drivers

| Component | Scaling | Notes |
|-----------|---------|-------|
| Systolic mesh | O(N²) | 256 PEs dominate area |
| SRAM banks | O(N²) | 4 banks, mixed widths |
| VAU | O(1) | LUT ROM + pipeline |
| Shader core | O(1) | Small relative to mesh |

### 7.2 Synthesis Status (v0.1)

| Block | Yosys synthesis | Notes |
|-------|-----------------|-------|
| `mac_unit` | Yes | `synth/yosys/mac_unit_syn.v` |
| `mac_array` | Yes | `synth/yosys/mac_array_syn.v` |
| `shader_core` | Yes | `synth/yosys/shader_core_syn.v` |
| `systolic_gemm` (256 PE) | Sim only | Controller loop unrolling needed for Yosys |

### 7.3 Future Area Work

- Synthesize full mesh with OpenROAD + SkyWater 130nm PDK
- Report LUT/FF and estimated area in µm²

---

## 8. Verification Strategy

### 8.1 Methodology

| Layer | Tool | Coverage |
|-------|------|----------|
| Golden models | Python (`verify/golden_*.py`) | Functional reference |
| Unit tests | pytest | MAC, array, shader, systolic, activation |
| RTL simulation | Icarus Verilog / Verilator | Testbenches in `tb/` |
| Lint | Verilator | RTL style and connectivity |
| Synthesis | Yosys | Selected blocks |

### 8.2 Key Test Cases

- MAC: single multiply, accumulate chain, signed overflow paths
- Shader core: multi-warp dot product (expected: 372 and 8)
- Systolic OS: 4×4, 8×8, 16×16 GEMM vs `matmul_reference`
- Systolic WS: same matrices, K-step cycle-accurate model
- Activation: ReLU, GeLU, SiLU vs floating-point reference

### 8.3 Regression

`scripts/run_all.ps1` runs: pytest → Verilator lint → simulation → Yosys synth

---

## 9. Design Trade-offs and Rationale

### 9.1 Why 16×16?

- Large enough to show real systolic timing (skew, drain)
- Small enough for simulation and eventual FPGA fit
- Matches common teaching / research array sizes

### 9.2 Why INT16 / 48-bit accum?

- INT16: halves operand bandwidth vs FP32; common in quantized inference
- 48-bit accum: holds worst-case sum of 16 products of 16×16-bit values without overflow

### 9.3 Why dual dataflow (OS + WS)?

- Demonstrates a key architecture knob in modern tensor units
- OS: simpler, fewer cycles for one-shot GEMM
- WS: models weight reuse patterns in CNNs

### 9.4 Why separate shader core?

- Illustrates GPU-style warp scheduling alongside dedicated systolic unit
- Not integrated into `systolic_accel` in v1 — future work could unify under one scheduler

---

## 10. Future Work and Roadmap

| Phase | Deliverable | Career value |
|-------|-------------|--------------|
| **1** | This architecture spec | System design, trade-off documentation |
| **2** | Randomized verification (1000+ matrices) | Verification discipline |
| **3** | OpenROAD synthesis + area/timing report | Physical awareness |
| **4** | Gate-level equivalence check | Signoff mindset |
| **5** | Technical blog / paper on OS vs WS | Communication |

**Architecture extensions (v2):**

- 32×32 tiling with external DRAM
- INT8 support and mixed precision
- Unified command processor for shader + systolic
- Host interface (AXI-Lite or UART for FPGA)

---

## 11. References

1. Jouppi, N. P., et al. *"In-Datacenter Performance Analysis of a Tensor Processing Unit."* ISCA 2017.
2. Kung, H. T., & Leiserson, C. E. *"Systolic Arrays (for VLSI)."* Sparse Matrix Proceedings, 1979.
3. Hennessy, J. L., & Patterson, D. A. *Computer Architecture: A Quantitative Approach.* (Domain-specific accelerators chapter.)
4. Project RTL: `rtl/`, golden models: `verify/`, shared parameters: `rtl/gpu_pkg.sv`

---

*TensorMesh-16 — Harshil Gor*

---

## Appendix A: ISA Encoding (Shader Core)

| Opcode | Value | Description |
|--------|-------|-------------|
| `OP_NOP` | `4'h0` | No operation |
| `OP_CLEAR` | `4'h1` | Clear MAC accumulator |
| `OP_MAC` | `4'h2` | MAC with chunk index in bits [25:24] |
| `OP_HALT` | `4'hF` | End warp execution |

## Appendix B: Shared Parameters (`gpu_pkg.sv`)

```systemverilog
MAC_WIDTH = 16          MAC_LANES = 4
NUM_WARPS = 2           WARP_SIZE = 32
SYSTOLIC_SIZE = 16      SYSTOLIC_WIDTH = 16
SYSTOLIC_ACC_W = 48     VAU_LATENCY = 3
MODE_OUTPUT_STATIONARY = 2'b00
MODE_WEIGHT_STATIONARY = 2'b01
```
