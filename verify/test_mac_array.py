"""Pytest tests for mac_array golden reference."""

from golden_mac_array import MacArrayPipelineModel, chunk_sum, dot_product_chunked


def test_single_chunk():
    a = [1, 2, 3, 4]
    b = [1, 3, 5, 7]
    assert chunk_sum(a, b) == 1 + 6 + 15 + 28


def test_dot_product_8_chunked():
    a = [i + 1 for i in range(8)]
    b = [2 * i + 1 for i in range(8)]
    expected = sum(ai * bi for ai, bi in zip(a, b))
    assert dot_product_chunked(a, b) == expected == 372


def test_signed_chunk():
    a = [-2, 3, -1, 4]
    b = [5, -4, -3, 2]
    assert chunk_sum(a, b) == -11


def test_pipeline_matches_chunked():
    a = [i + 1 for i in range(8)]
    b = [2 * i + 1 for i in range(8)]
    ref = dot_product_chunked(a, b)

    model = MacArrayPipelineModel()
    for i in range(0, 8, 4):
        model.tick(valid=True, a=a[i : i + 4], b=b[i : i + 4])
    model.tick()
    model.tick()

    assert model.acc == ref
