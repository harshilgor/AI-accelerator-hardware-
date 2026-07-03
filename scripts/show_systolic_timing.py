#!/usr/bin/env python3
"""Print systolic array timing diagrams for AI/ML GEMM acceleration."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "verify"))

from golden_systolic import (  # noqa: E402
    SystolicModel,
    format_injection_schedule,
    format_mesh_wave,
    matmul_reference,
    pe_meet_cycle,
)


def demo_matrix(size: int) -> tuple[list[list[int]], list[list[int]]]:
    """Simple demo: A = i*j pattern, B = identity (isolates rows of A)."""
    a = [[(i + 1) * (j + 1) for j in range(size)] for i in range(size)]
    b = [[1 if i == j else 0 for j in range(size)] for i in range(size)]
    return a, b


def main() -> None:
    parser = argparse.ArgumentParser(description="Systolic array timing visualization")
    parser.add_argument("--size", type=int, default=4, choices=[4, 8, 16],
                        help="Mesh size NxN (default: 4 for readable diagrams)")
    parser.add_argument("--waves", action="store_true",
                        help="Show per-cycle MAC activity across the mesh")
    args = parser.parse_args()

    size = args.size
    a, b = demo_matrix(size)

    print(format_injection_schedule(size, a, b))
    print()

    if args.waves:
        print("=" * 72)
        print("MAC products firing per cycle (what each PE computes)")
        print("=" * 72)
        max_cycle = 3 * size - 2
        for t in range(max_cycle + 1):
            active = any(pe_meet_cycle(i, j, k) == t
                         for i in range(size) for j in range(size) for k in range(size))
            if active:
                print(format_mesh_wave(size, t, a, b))
                print()

    ref = matmul_reference(a, b)
    sim = SystolicModel(size=size).run(a, b)
    print("=" * 72)
    print(f"Result check ({size}x{size}, C = A x B)")
    print("=" * 72)
    print("Reference C (software matmul):")
    for row in ref:
        print("  " + " ".join(f"{v:6d}" for v in row))
    print()
    print("Systolic model C:")
    for row in sim:
        print("  " + " ".join(f"{v:6d}" for v in row))
    print()
    print("MATCH" if sim == ref else "MISMATCH")


if __name__ == "__main__":
    main()
