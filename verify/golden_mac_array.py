"""Golden reference for mac_array.v — parallel lane dot-product chunks."""

from __future__ import annotations


def chunk_sum(
    a_chunk: list[int],
    b_chunk: list[int],
    *,
    width: int = 16,
) -> int:
    """Sum of products for one chunk (one valid cycle)."""
    acc_w = 2 * width + 2
    total = 0
    for a, b in zip(a_chunk, b_chunk):
        product = _to_signed(a * b, 2 * width)
        total = _to_signed(total + product, acc_w)
    return _to_signed(total, acc_w)


def dot_product_chunked(
    a_vec: list[int],
    b_vec: list[int],
    *,
    lanes: int = 4,
    width: int = 16,
) -> int:
    """Full dot product using LANES-wide chunks."""
    assert len(a_vec) == len(b_vec)
    assert len(a_vec) % lanes == 0

    acc_w = 2 * width + 2
    acc = 0
    for i in range(0, len(a_vec), lanes):
        acc = _to_signed(
            acc + chunk_sum(a_vec[i : i + lanes], b_vec[i : i + lanes], width=width),
            acc_w,
        )
    return acc


def _to_signed(value: int, bit_width: int) -> int:
    value &= (1 << bit_width) - 1
    if value >= (1 << (bit_width - 1)):
        return value - (1 << bit_width)
    return value


class MacArrayPipelineModel:
    """Cycle-accurate 2-stage model of mac_array."""

    def __init__(self, *, width: int = 16, lanes: int = 4) -> None:
        self.width = width
        self.lanes = lanes
        self.acc_w = 2 * width + 2
        self.acc = 0
        self.s1_valid = False
        self.s1_clear = False
        self.s1_products: list[int] = [0] * lanes
        self.result_valid = False

    def tick(
        self,
        *,
        valid: bool = False,
        clear: bool = False,
        a: list[int] | None = None,
        b: list[int] | None = None,
    ) -> int:
        a = a or [0] * self.lanes
        b = b or [0] * self.lanes

        next_s1_valid = valid
        next_s1_clear = clear
        next_products = [
            _to_signed(a[i] * b[i], 2 * self.width) for i in range(self.lanes)
        ]

        lane_sum = 0
        for p in self.s1_products:
            lane_sum = _to_signed(lane_sum + p, self.acc_w)

        if self.s1_clear:
            next_acc = 0
        elif self.s1_valid:
            next_acc = _to_signed(self.acc + lane_sum, self.acc_w)
        else:
            next_acc = self.acc

        self.s1_valid = next_s1_valid
        self.s1_clear = next_s1_clear
        self.s1_products = next_products
        self.acc = next_acc
        self.result_valid = self.s1_valid

        return self.acc
