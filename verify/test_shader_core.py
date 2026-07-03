"""Pytest tests for shader_core golden reference."""

from golden_shader_core import shader_core_reference


def test_shader_core_warp_results():
    results = shader_core_reference()
    assert results[0] == 372
    assert results[1] == 8
