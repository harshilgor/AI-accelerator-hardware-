"""
Golden reference model for mac_unit.v

Mirrors the pipelined MAC behavior in software so you can cross-check
RTL simulation results with pytest before synthesis.
"""

from __future__ import annotations

from dataclasses import dataclass, field


def mac_reference(
    ops: list[tuple[int, int]],
    *,
    width: int = 16,
    clear_before: bool = True,
) -> int:
    """
    Compute accumulator result for a sequence of (a, b) multiply-accumulates.

    Models the *logical* MAC (not cycle-accurate pipeline). Use
  `simulate_mac_pipeline` for cycle-accurate checks.
    """
    mask = (1 << (2 * width)) - 1
    max_acc = 1 << (2 * width - 1)
    min_acc = -(1 << (2 * width - 1))

    acc = 0
    if clear_before:
        acc = 0

    for a, b in ops:
        product = _saturate_width(a * b, 2 * width)
        acc = _saturate_width(acc + product, 2 * width)

    return _to_signed(acc, 2 * width)


def _to_signed(value: int, bit_width: int) -> int:
    value &= (1 << bit_width) - 1
    if value >= (1 << (bit_width - 1)):
        return value - (1 << bit_width)
    return value


def _saturate_width(value: int, bit_width: int) -> int:
    """Wrap to bit_width two's complement (matches Verilog signed reg behavior)."""
    return _to_signed(value, bit_width)


@dataclass
class MacPipelineModel:
    """Cycle-accurate model of the 2-stage pipelined mac_unit."""

    width: int = 16
    acc: int = 0
    s1_valid: bool = False
    s1_clear: bool = False
    s1_product: int = 0
    acc_valid: bool = False

    def tick(
        self,
        *,
        valid: bool = False,
        clear: bool = False,
        a: int = 0,
        b: int = 0,
    ) -> int:
        """Advance one clock cycle; return accumulator value after the edge."""
        # Stage 1 (inputs sampled on posedge)
        next_s1_valid = valid
        next_s1_clear = clear
        next_s1_product = _saturate_width(a * b, 2 * self.width)

        # Stage 2
        if self.s1_clear:
            next_acc = 0
        elif self.s1_valid:
            next_acc = _saturate_width(
                self.acc + self.s1_product, 2 * self.width
            )
        else:
            next_acc = self.acc

        next_acc_valid = self.s1_valid

        # Commit
        self.s1_valid = next_s1_valid
        self.s1_clear = next_s1_clear
        self.s1_product = next_s1_product
        self.acc = next_acc
        self.acc_valid = next_acc_valid

        return self.acc

    def run_ops(self, cycles: list[dict]) -> list[tuple[int, bool]]:
        """
        Run a list of per-cycle dicts with keys: valid, clear, a, b.
        Returns list of (acc, acc_valid) after each cycle.
        """
        trace = []
        for c in cycles:
            acc = self.tick(
                valid=c.get("valid", False),
                clear=c.get("clear", False),
                a=c.get("a", 0),
                b=c.get("b", 0),
            )
            trace.append((acc, self.acc_valid))
        return trace


def dot_product_reference(a_vec: list[int], b_vec: list[int], width: int = 16) -> int:
    assert len(a_vec) == len(b_vec)
    return mac_reference(list(zip(a_vec, b_vec)), width=width)
