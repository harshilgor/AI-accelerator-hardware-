"""Tests for systolic GEMM golden model."""

from golden_systolic import (
    DataflowMode,
    SystolicModel,
    format_injection_schedule,
    format_mesh_wave,
    matmul_reference,
    pe_meet_cycle,
)


def test_pe_meet_timing():
    assert pe_meet_cycle(0, 0, 0) == 0
    assert pe_meet_cycle(1, 2, 1) == 4
    assert pe_meet_cycle(3, 3, 3) == 9


def test_4x4_matmul_matches_reference():
    a = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
    b = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    ref = matmul_reference(a, b, width=16)
    sim = SystolicModel(size=4).run(a, b)
    assert sim == ref


def test_8x8_matmul():
    size = 8
    a = [[(i + 1) * (j + 1) for j in range(size)] for i in range(size)]
    b = [[1 if i == j else 0 for j in range(size)] for i in range(size)]
    ref = matmul_reference(a, b, width=16)
    sim = SystolicModel(size=8).run(a, b)
    assert sim == ref


def test_16x16_matmul():
    size = 16
    a = [[(i + 1) * (j + 1) for j in range(size)] for i in range(size)]
    b = [[1 if i == j else 0 for j in range(size)] for i in range(size)]
    ref = matmul_reference(a, b, width=16)
    sim = SystolicModel(size=16).run(a, b)
    assert sim == ref


def test_dataflow_modes_match_reference_4x4():
    size = 4
    a = [[(i + 2) * (j + 1) - 3 for j in range(size)] for i in range(size)]
    b = [[(i - j) for j in range(size)] for i in range(size)]
    ref = matmul_reference(a, b, width=16)
    model = SystolicModel(size=size)
    sim_os = model.run(a, b, mode=DataflowMode.OUTPUT_STATIONARY)
    sim_ws = model.run(a, b, mode=DataflowMode.WEIGHT_STATIONARY)
    assert sim_os == ref
    assert sim_ws == ref


def test_ws_cycle_accurate_matches_reference_8x8():
    size = 8
    a = [[(i + 1) * (j + 1) for j in range(size)] for i in range(size)]
    b = [[1 if i == j else 0 for j in range(size)] for i in range(size)]
    ref = matmul_reference(a, b, width=16)
    sim = SystolicModel(size=size).run(a, b, mode=DataflowMode.WEIGHT_STATIONARY)
    assert sim == ref


def test_injection_schedule_renders():
    text = format_injection_schedule(4)
    assert "Systolic GEMM injection schedule" in text
    assert "cycle" in text


def test_mesh_wave_renders():
    a = [[1, 2, 3, 4], [5, 6, 7, 8], [9, 10, 11, 12], [13, 14, 15, 16]]
    b = [[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, 1]]
    text = format_mesh_wave(4, 0, a, b)
    assert "Mesh activity @ cycle 0" in text
    assert "+   1" in text
