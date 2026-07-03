"""Random and corner-case matrix generators for systolic verification."""

from __future__ import annotations

import random
from typing import Iterator

INT16_MIN = -(1 << 15)
INT16_MAX = (1 << 15) - 1

# Default PRNG seed for reproducible regression (documented in docs/VERIFICATION.md).
DEFAULT_SEED = 42


def clip_int16(value: int) -> int:
    return max(INT16_MIN, min(INT16_MAX, value))


def random_int16_matrix(size: int, rng: random.Random) -> list[list[int]]:
    return [
        [rng.randint(INT16_MIN, INT16_MAX) for _ in range(size)]
        for _ in range(size)
    ]


def zero_matrix(size: int) -> list[list[int]]:
    return [[0] * size for _ in range(size)]


def identity_matrix(size: int) -> list[list[int]]:
    return [[1 if i == j else 0 for j in range(size)] for i in range(size)]


def corner_cases(size: int) -> list[tuple[str, list[list[int]], list[list[int]]]]:
    """Named corner-case matrix pairs for a given dimension."""
    cases: list[tuple[str, list[list[int]], list[list[int]]]] = []

    cases.append(("zeros", zero_matrix(size), zero_matrix(size)))
    cases.append(("identity_x_identity", identity_matrix(size), identity_matrix(size)))
    cases.append(("a_identity", identity_matrix(size), random_int16_matrix(size, random.Random(1))))
    cases.append(("b_identity", random_int16_matrix(size, random.Random(2)), identity_matrix(size)))

    max_a = [[INT16_MAX] * size for _ in range(size)]
    max_b = [[1 if j == 0 else 0 for j in range(size)] for _ in range(size)]
    cases.append(("max_int16_col", max_a, max_b))

    min_a = [[INT16_MIN if j == 0 else 0 for j in range(size)] for _ in range(size)]
    min_b = [[INT16_MIN if i == 0 else 0 for j in range(size)] for i in range(size)]
    cases.append(("min_int16_sparse", min_a, min_b))

    single = zero_matrix(size)
    single[0][0] = 42
    single_b = zero_matrix(size)
    single_b[0][0] = 7
    cases.append(("single_element", single, single_b))

    alt = [[INT16_MAX if (i + j) % 2 == 0 else INT16_MIN for j in range(size)] for i in range(size)]
    cases.append(("checkerboard_extremes", alt, identity_matrix(size)))

    return cases


def random_matrix_pairs(
    *,
    count: int,
    size: int,
    seed: int = DEFAULT_SEED,
) -> Iterator[tuple[list[list[int]], list[list[int]]]]:
    rng = random.Random(seed)
    for _ in range(count):
        yield random_int16_matrix(size, rng), random_int16_matrix(size, rng)
