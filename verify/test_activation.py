"""Tests for VAU golden activation model."""

from golden_activation import apply_activation, gelu_f, relu_f, silu_f


def test_relu_hardware():
    assert apply_activation(5, 0) == 5
    assert apply_activation(-3, 0) == 0


def test_gelu_near_zero():
    z = apply_activation(0, 1)
    assert -1 <= z <= 1


def test_silu_negative():
    out = apply_activation(-1, 2)
    assert out < 0


def test_float_refs():
    assert relu_f(-1.0) == 0.0
    assert gelu_f(0.0) == 0.0
    assert abs(silu_f(0.0)) < 1e-9
