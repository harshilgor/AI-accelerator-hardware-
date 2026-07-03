# LinkedIn Post — TensorMesh-16 (OS vs WS Systolic GEMM)

Copy-paste ready. Replace the repo URL if needed.

---

## Version A — Short (~1,300 characters)

I just finished **TensorMesh-16** — a configurable INT16 AI accelerator in SystemVerilog, built as a portfolio project for computer architecture.

The core idea: a **16×16 systolic array** (256 MAC processing elements) that computes matrix multiply (GEMM) with a runtime-selectable dataflow — the same architectural knob you see in production tensor hardware.

**Two modes, one mesh:**

→ **Output-stationary (OS)** — partial sums stay in each PE; operands stream through. ~63 cycles for 16×16 GEMM. Best for low-latency dense layers.

→ **Weight-stationary (WS)** — weights latch into local registers; activations stream per k-slice. ~1009 cycles on this mesh, but models CNN-style weight reuse and lower B-bandwidth during compute.

Both modes produce **bit-identical results** — verified with 1,700+ randomized matrices, cycle-accurate Python golden models, Verilator/Icarus sim, and Yosys gate-level cosim.

Full stack:
• SystemVerilog RTL (systolic mesh, fused ReLU/GeLU/SiLU, warp-scheduled shader core)
• Dual dataflow controller (OS + WS)
• pytest + golden models
• Yosys synthesis (~1.3M cells extrapolated for full mesh)
• Technical write-up on OS vs WS trade-offs

Repo: https://github.com/harshilgor/AI-accelerator-hardware-

If you're into systolic arrays, TPUs, or RTL verification — would love your feedback.

#ComputerArchitecture #Hardware #SystemVerilog #AI #MachineLearning #RTL #FPGA #ASIC #EmbeddedSystems

---

## Version B — Hook-first (~900 characters)

Same PE mesh. Same SRAM. Same 256 MACs.

**63 cycles** in one mode. **~1009 cycles** in the other.

Both compute the exact same 16×16 INT16 GEMM.

That's the output-stationary vs weight-stationary trade-off — a first-class decision in tensor accelerators (Google TPU and friends). I implemented both in **TensorMesh-16**, my SystemVerilog INT16 accelerator project:

• Skewed operand injection (OS) vs K-step weight preload (WS)
• Cycle-accurate golden models + 1,700 randomized tests
• Fused activations, 4-bank SRAM, Yosys synthesis path

The cycle gap isn't a bug — it's *when* you pay to move weights vs activations.

Write-up + RTL: https://github.com/harshilgor/AI-accelerator-hardware-

#ComputerArchitecture #SystemVerilog #AIHardware #SystolicArray

---

## Version C — Bullet list (easy scan)

**Built an INT16 systolic accelerator in SystemVerilog — TensorMesh-16**

What it does:
✓ 16×16 GEMM on a 256-PE systolic mesh
✓ Runtime OS / WS dataflow switch
✓ Fused ReLU, GeLU, SiLU activation unit
✓ 4-bank on-chip SRAM + full accel pipeline

How I verified it:
✓ Python cycle-accurate golden models
✓ 1,700+ randomized OS/WS cross-checks
✓ Verilator + Icarus simulation
✓ Yosys synthesis + gate-level RTL/netlist cosim

Key insight: OS wins latency (~63 cyc); WS models weight reuse (~1009 cyc on N=16) — same math, different memory/compute schedule.

📄 Technical write-up: docs/WRITEUP.md in repo
🔗 https://github.com/harshilgor/AI-accelerator-hardware-

Open to roles in computer architecture / RTL / AI hardware.

#ComputerArchitecture #RTL #AI #HardwareDesign

---

## Suggested image / diagram

Use a screenshot from:
```powershell
python scripts/show_systolic_timing.py --size 4
```
Paste the injection schedule table as a carousel slide or code screenshot.

---

*TensorMesh-16 — Harshil Gor*
