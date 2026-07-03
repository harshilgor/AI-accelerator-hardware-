# TensorMesh-16 — Verification Report

**Author:** Harshil Gor  
**Last updated:** July 2026  
**Status:** Phase 2 complete — randomized golden-model regression

---

## 1. Overview

TensorMesh-16 is verified using a **golden-model methodology**: Python reference models mirror RTL semantics (or cycle-accurate schedules for systolic GEMM), and pytest compares simulated behavior against software references.

This document summarizes test coverage, randomized regression scale, corner cases, and how to reproduce results.

---

## 2. Verification stack

| Layer | Tool | Location |
|-------|------|----------|
| Golden models | Python | `verify/golden_*.py` |
| Unit / regression tests | pytest | `verify/test_*.py` |
| RTL simulation | Icarus / Verilator | `tb/`, `scripts/verilator_sim.ps1` |
| Lint | Verilator | `scripts/verilator_lint.ps1` |
| Synthesis (selected blocks) | Yosys | `scripts/yosys_synth.ps1` |

**Full regression command:**

```powershell
python -m pytest verify/ -v
```

**RTL + synthesis stack:**

```powershell
.\scripts\run_all.ps1
```

---

## 3. Golden model map

| RTL block | Golden model | Test file |
|-----------|--------------|-----------|
| `mac_unit` | `golden_mac.py` | `test_mac.py` |
| `mac_array` | `golden_mac_array.py` | `test_mac_array.py` |
| `shader_core` | `golden_shader_core.py` | `test_shader_core.py` |
| `systolic_gemm` (OS + WS) | `golden_systolic.py` | `test_systolic.py`, `test_random_systolic.py` |
| `act_unit` / `vau` | `golden_activation.py` | `test_activation.py` |

---

## 4. Phase 2 — Randomized systolic regression

### 4.1 Methodology

- Matrices are **16-bit signed** (`INT16_MIN` … `INT16_MAX`).
- Reference: `matmul_reference()` with 48-bit accumulation (matches `SYSTOLIC_ACC_W`).
- Simulators: cycle-accurate `SystolicModel` in **output-stationary (OS)** and **weight-stationary (WS)** modes.
- **Fixed PRNG seeds** for reproducibility (`random_matrices.DEFAULT_SEED = 42`).

### 4.2 Trial counts

| Test | Size | Mode | Trials | Seed offset |
|------|------|------|--------|-------------|
| `test_random_os_size4` | 4×4 | OS | 500 | 42 |
| `test_random_ws_size4` | 4×4 | WS | 500 | 43 |
| `test_random_os_size8` | 8×8 | OS | 200 | 44 |
| `test_random_ws_size8` | 8×8 | WS | 200 | 45 |
| `test_random_os_size16` | 16×16 | OS | 150 | 46 |
| `test_random_ws_size16` | 16×16 | WS | 150 | 47 |

**Total randomized mode-runs:** **1,700** (guardrailed by `test_total_random_trial_count_meets_goal` ≥ 1,000).

### 4.3 Cross-mode agreement

`test_os_and_ws_agree_on_random` verifies OS, WS, and `matmul_reference` all agree:

| Mesh size | Additional trials |
|-----------|-------------------|
| 4×4 | 100 |
| 8×8 | 100 |
| 16×16 | 50 |

### 4.4 Corner cases

`test_corner_cases` runs named edge matrices at sizes 4, 8, and 16 in **both** OS and WS modes:

| Case | Description |
|------|-------------|
| `zeros` | A = 0, B = 0 |
| `identity_x_identity` | I × I |
| `a_identity` | I × random B |
| `b_identity` | random A × I |
| `max_int16_col` | All MAX_INT16 × sparse B |
| `min_int16_sparse` | Sparse MIN_INT16 operands |
| `single_element` | Single non-zero in A and B |
| `checkerboard_extremes` | Alternating MAX/MIN × I |

**Corner-case executions:** 8 cases × 3 sizes × 2 modes = **48**.

### 4.5 Results (local run)

```
pytest verify/ -q
36 passed in ~10–15s
```

| Metric | Value |
|--------|-------|
| Total pytest tests | 36 |
| Randomized mode-runs | 1,700 |
| Cross-mode trials | 250 |
| Corner-case runs | 48 |
| Pass rate | **100%** |
| Default seed | **42** |

---

## 5. Deterministic systolic tests (Phase 1)

| Test | Description |
|------|-------------|
| `test_4x4_matmul_matches_reference` | Fixed 4×4 vs reference |
| `test_8x8_matmul` | Structured 8×8 |
| `test_16x16_matmul` | Full mesh size |
| `test_dataflow_modes_match_reference_4x4` | OS + WS 4×4 |
| `test_ws_cycle_accurate_matches_reference_8x8` | WS schedule 8×8 |
| `test_pe_meet_timing` | Injection schedule timing |

---

## 6. RTL simulation status

RTL testbenches exist for all major blocks. Randomized pytest validates **golden models** that RTL is checked against; RTL sim uses deterministic testbenches.

| Testbench | Block | Notes |
|-----------|-------|-------|
| `mac_unit_tb` | MAC | Pipeline + dot product |
| `mac_array_tb` | MAC array | Chunked sum |
| `shader_core_tb` | Shader core | Multi-warp |
| `systolic_gemm_tb` | GEMM | OS + WS 16×16 |
| `systolic_accel_tb` | Full pipeline | SRAM → GEMM → VAU |
| `sram_tb` | SRAM | Memory |
| `vau_tb` | VAU | Activations |

**Known gap (Phase 3+):** Randomized matrices are not yet fed directly into RTL sim in CI — only into Python golden models. Closing this gap is optional future work (cocotb or test vector export).

---

## 7. Reproducing randomized tests

```powershell
# All randomized systolic tests
python -m pytest verify/test_random_systolic.py -v

# Full verify suite
python -m pytest verify/ -v
```

To change trial volume, edit constants at the top of `verify/test_random_systolic.py`:

```python
RANDOM_TRIALS_SIZE4 = 500
RANDOM_TRIALS_SIZE8 = 200
RANDOM_TRIALS_SIZE16_OS = 150
RANDOM_TRIALS_SIZE16_WS = 150
```

---

## 8. Roadmap

| Phase | Goal | Status |
|-------|------|--------|
| 1 | Architecture specification | Done |
| 2 | Randomized verification | **Done** — [docs/VERIFICATION.md](docs/VERIFICATION.md) |
| 3 | OpenROAD synthesis + area/timing | Planned |
| 4 | Gate-level equivalence | Planned |
| 5 | Technical write-up | Planned |

---

## 9. What we need from you (optional)

Nothing is required to run Phase 2 locally — tests pass out of the box.

**Optional help for Phase 3:**

1. **GitHub Actions** — confirm CI runs `pytest verify/` on push (you did Step 1; if workflow exists, randomized tests run automatically).
2. **Push to GitHub** — after pulling these changes, push so CI reflects 36 tests.
3. **SkyWater / OpenROAD** — if you install the open PDK toolchain locally, we can generate real area numbers for `docs/SYNTHESIS.md` in Phase 3.

---

*TensorMesh-16 — Harshil Gor*
