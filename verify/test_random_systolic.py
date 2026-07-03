"""Large-scale randomized verification for systolic GEMM (OS and WS)."""

from __future__ import annotations

import random

import pytest

from golden_systolic import DataflowMode, SystolicModel, matmul_reference
from random_matrices import DEFAULT_SEED, corner_cases, random_matrix_pairs

WIDTH = 16
ACC_W = 48

# Trial counts — sized for CI runtime vs coverage (see docs/VERIFICATION.md).
RANDOM_TRIALS_SIZE4 = 500
RANDOM_TRIALS_SIZE8 = 200
RANDOM_TRIALS_SIZE16_OS = 150
RANDOM_TRIALS_SIZE16_WS = 150


def _assert_gemm_matches(
    a: list[list[int]],
    b: list[list[int]],
    *,
    size: int,
    mode: DataflowMode,
    label: str,
) -> None:
    ref = matmul_reference(a, b, width=WIDTH, acc_w=ACC_W)
    sim = SystolicModel(size=size).run(a, b, mode=mode)
    assert sim == ref, f"{label}: mode={mode.name} mismatch"


def _run_random_batch(
    *,
    size: int,
    count: int,
    mode: DataflowMode,
    seed: int,
) -> None:
    for trial, (a, b) in enumerate(random_matrix_pairs(count=count, size=size, seed=seed)):
        _assert_gemm_matches(a, b, size=size, mode=mode, label=f"random s={size} t={trial}")


def test_random_os_size4():
    _run_random_batch(
        size=4,
        count=RANDOM_TRIALS_SIZE4,
        mode=DataflowMode.OUTPUT_STATIONARY,
        seed=DEFAULT_SEED,
    )


def test_random_ws_size4():
    _run_random_batch(
        size=4,
        count=RANDOM_TRIALS_SIZE4,
        mode=DataflowMode.WEIGHT_STATIONARY,
        seed=DEFAULT_SEED + 1,
    )


def test_random_os_size8():
    _run_random_batch(
        size=8,
        count=RANDOM_TRIALS_SIZE8,
        mode=DataflowMode.OUTPUT_STATIONARY,
        seed=DEFAULT_SEED + 2,
    )


def test_random_ws_size8():
    _run_random_batch(
        size=8,
        count=RANDOM_TRIALS_SIZE8,
        mode=DataflowMode.WEIGHT_STATIONARY,
        seed=DEFAULT_SEED + 3,
    )


def test_random_os_size16():
    _run_random_batch(
        size=16,
        count=RANDOM_TRIALS_SIZE16_OS,
        mode=DataflowMode.OUTPUT_STATIONARY,
        seed=DEFAULT_SEED + 4,
    )


def test_random_ws_size16():
    _run_random_batch(
        size=16,
        count=RANDOM_TRIALS_SIZE16_WS,
        mode=DataflowMode.WEIGHT_STATIONARY,
        seed=DEFAULT_SEED + 5,
    )


@pytest.mark.parametrize("size", [4, 8, 16])
def test_os_and_ws_agree_on_random(size: int):
    """OS and WS golden models must match each other and the reference."""
    rng = random.Random(DEFAULT_SEED + 100 + size)
    trials = 50 if size == 16 else 100
    model = SystolicModel(size=size)
    for trial in range(trials):
        a = [[rng.randint(-(1 << 15), (1 << 15) - 1) for _ in range(size)] for _ in range(size)]
        b = [[rng.randint(-(1 << 15), (1 << 15) - 1) for _ in range(size)] for _ in range(size)]
        ref = matmul_reference(a, b, width=WIDTH, acc_w=ACC_W)
        sim_os = model.run(a, b, mode=DataflowMode.OUTPUT_STATIONARY)
        sim_ws = model.run(a, b, mode=DataflowMode.WEIGHT_STATIONARY)
        assert sim_os == ref, f"OS mismatch size={size} trial={trial}"
        assert sim_ws == ref, f"WS mismatch size={size} trial={trial}"
        assert sim_os == sim_ws, f"OS != WS size={size} trial={trial}"


@pytest.mark.parametrize("size", [4, 8, 16])
def test_corner_cases(size: int):
    for name, a, b in corner_cases(size):
        for mode in DataflowMode:
            _assert_gemm_matches(a, b, size=size, mode=mode, label=f"corner {name}")


def test_total_random_trial_count_meets_goal():
    """Guardrail: keep aggregate randomized mode-runs above 1000."""
    total = (
        RANDOM_TRIALS_SIZE4 * 2
        + RANDOM_TRIALS_SIZE8 * 2
        + RANDOM_TRIALS_SIZE16_OS
        + RANDOM_TRIALS_SIZE16_WS
    )
    assert total >= 1000, f"expected >= 1000 randomized mode-runs, got {total}"
