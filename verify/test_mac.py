"""Pytest tests for mac_unit golden reference model."""

from golden_mac import MacPipelineModel, dot_product_reference, mac_reference


def test_single_mac():
    assert mac_reference([(3, 4)]) == 12


def test_accumulate_chain():
    assert mac_reference([(3, 4), (2, 5), (1, 7), (4, 3)]) == 41


def test_signed_negative():
    assert mac_reference([(-3, 4)]) == -12
    assert mac_reference([(-3, 4), (-2, -5)]) == -2


def test_dot_product_8():
    a = [i + 1 for i in range(8)]
    b = [2 * i + 1 for i in range(8)]
    expected = sum(ai * bi for ai, bi in zip(a, b))
    assert dot_product_reference(a, b) == expected


def test_pipeline_clear():
    model = MacPipelineModel()
    model.tick(valid=True, a=3, b=4)
    model.tick()
    model.tick()

    trace = model.run_ops([{"clear": True}, {}, {}])
    assert trace[-1][0] == 0


def test_pipeline_matches_reference():
    ops = [(3, 4), (2, 5), (1, 7), (4, 3)]
    ref = mac_reference(ops)

    model = MacPipelineModel()
    for a, b in ops:
        model.tick(valid=True, a=a, b=b)
    model.tick()
    model.tick()

    assert model.acc == ref
