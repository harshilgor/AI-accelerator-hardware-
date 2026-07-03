"""Golden reference for shader_core — multi-warp dot product."""

from __future__ import annotations

from golden_mac_array import dot_product_chunked


def warp0_vectors() -> tuple[list[int], list[int]]:
    a = [i + 1 for i in range(8)]
    b = [2 * i + 1 for i in range(8)]
    return a, b


def warp1_vectors() -> tuple[list[int], list[int]]:
    return [1] * 8, [1] * 8


def shader_core_reference() -> list[int]:
    a0, b0 = warp0_vectors()
    a1, b1 = warp1_vectors()
    return [
        dot_product_chunked(a0, b0),
        dot_product_chunked(a1, b1),
    ]


def test_shader_core_warp_results():
    results = shader_core_reference()
    assert results[0] == 372
    assert results[1] == 8
