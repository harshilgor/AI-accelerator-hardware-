"""Golden activation functions + hardware VAU piecewise-linear model."""

from __future__ import annotations

import math

SEGMENTS = 64
X_MIN = -8.0
X_MAX = 8.0
FRAC_BITS = 16
Q = 1 << FRAC_BITS
FRAC_W = 14


def relu_f(x: float) -> float:
    return max(0.0, x)


def gelu_f(x: float) -> float:
    return x * 0.5 * (1.0 + math.tanh(math.sqrt(2.0 / math.pi) * (x + 0.044715 * x**3)))


def silu_f(x: float) -> float:
    if x > 20:
        return x
    if x < -20:
        return 0.0
    return x / (1.0 + math.exp(-x))


def _to_signed(value: int, bit_width: int) -> int:
    value &= (1 << bit_width) - 1
    if value >= (1 << (bit_width - 1)):
        return value - (1 << bit_width)
    return value


def _quantize_out(y_q: int, out_w: int = 16) -> int:
    rounded = y_q >> FRAC_BITS
    hi = (1 << (out_w - 1)) - 1
    lo = -(1 << (out_w - 1))
    return _to_signed(max(lo, min(hi, rounded)), out_w)


def _to_x_q(acc: int) -> int:
    promoted = acc << FRAC_BITS
    hi = int(X_MAX * Q)
    lo = int(X_MIN * Q)
    return max(lo, min(hi, promoted))


def _build_hw_lut(fn) -> tuple[list[int], list[int]]:
    step = (X_MAX - X_MIN) / SEGMENTS
    y_base: list[int] = []
    slope: list[int] = []
    for i in range(SEGMENTS):
        x0 = X_MIN + i * step
        x1 = x0 + step
        y0 = fn(x0)
        y1 = fn(x1)
        y_base.append(int(round(y0 * Q)))
        slope.append(int(round(((y1 - y0) / step) * Q)))
    return y_base, slope


GELU_Y, GELU_M = _build_hw_lut(gelu_f)
SILU_Y, SILU_M = _build_hw_lut(silu_f)


def apply_activation(acc: int, mode: int, *, out_w: int = 16) -> int:
    """Combinational model matching act_unit RTL (post-pipeline semantics)."""
    x_q = _to_x_q(acc)
    if mode == 0:
        y_q = 0 if x_q < 0 else x_q
    else:
        x_min_q = int(X_MIN * Q)
        span_q = int((X_MAX - X_MIN) * Q)
        offset = max(0, min(span_q, x_q - x_min_q))
        seg = min(SEGMENTS - 1, offset >> FRAC_W)
        frac = offset & ((1 << FRAC_W) - 1)
        if mode == 1:
            y_b, slope = GELU_Y[seg], GELU_M[seg]
        else:
            y_b, slope = SILU_Y[seg], SILU_M[seg]
        y_q = y_b + ((slope * frac) >> FRAC_W)
    return _quantize_out(y_q, out_w)


def apply_activation_float(x: float, mode: int) -> float:
    if mode == 0:
        return relu_f(x)
    if mode == 1:
        return gelu_f(x)
    return silu_f(x)
