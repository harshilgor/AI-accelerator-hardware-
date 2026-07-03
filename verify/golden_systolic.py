"""Golden reference and cycle-accurate model for systolic_gemm."""

from __future__ import annotations

from enum import IntEnum


class DataflowMode(IntEnum):
    OUTPUT_STATIONARY = 0
    WEIGHT_STATIONARY = 1


def matmul_reference(
    a: list[list[int]],
    b: list[list[int]],
    *,
    width: int = 16,
    acc_w: int = 48,
) -> list[list[int]]:
    """Software matrix multiply C = A x B."""
    size = len(a)
    assert len(b) == size and all(len(row) == size for row in a)
    assert all(len(row) == size for row in b)

    c = [[0] * size for _ in range(size)]
    for i in range(size):
        for j in range(size):
            total = 0
            for k in range(size):
                prod = _to_signed(a[i][k] * b[k][j], 2 * width)
                total = _to_signed(total + prod, acc_w)
            c[i][j] = total
    return c


def injection_events(
    size: int,
) -> list[tuple[int, str, int, int, int]]:
    """Return (cycle, kind, row_or_k, col_or_j, value_index) events sorted by cycle."""
    events: list[tuple[int, str, int, int, int]] = []
    for k in range(size):
        for i in range(size):
            events.append((i + k, "A", i, k, 0))
        for j in range(size):
            events.append((j + k, "B", k, j, 0))
    events.sort(key=lambda e: (e[0], e[1], e[2], e[3]))
    return events


def pe_meet_cycle(i: int, j: int, k: int) -> int:
    """Cycle when A[i][k] and B[k][j] meet at PE(i,j)."""
    return i + j + k


def ws_slice_len(size: int) -> int:
    """Cycles per WS preload or run slice (last PE at row/col SIZE-1)."""
    return 2 * size - 2


def format_injection_schedule(
    size: int,
    a: list[list[int]] | None = None,
    b: list[list[int]] | None = None,
) -> str:
    """ASCII timing diagram of operand injection at mesh edges."""
    lines: list[str] = []
    max_cycle = 3 * size - 2
    lines.append(f"Systolic GEMM injection schedule ({size}x{size} mesh)")
    lines.append("=" * 72)
    lines.append("")
    lines.append("Legend:  A[i][k] -> row i (flows right)   B[k][j] -> col j (flows down)")
    lines.append("         PE(i,j) MAC at cycle (i + j + k) for each k")
    lines.append("")

    header = "cycle | " + " ".join(f"r{r}" for r in range(size))
    lines.append(header)
    lines.append("-" * len(header))

    for t in range(max_cycle + 1):
        row_vals = ["  ."] * size
        col_vals = ["  ."] * size
        for k in range(size):
            for i in range(size):
                if i + k == t:
                    val = a[i][k] if a else k
                    row_vals[i] = f"{val:3d}" if a else f"a{i}{k}"
            for j in range(size):
                if j + k == t:
                    val = b[k][j] if b else k
                    col_vals[j] = f"{val:3d}" if b else f"b{k}{j}"

        a_part = " ".join(row_vals)
        b_part = " ".join(col_vals)
        lines.append(f"{t:5d} | A: {a_part}  ||  B: {b_part}")

    lines.append("")
    lines.append("PE meet times (i+j+k) for k=0..K-1:")
    for i in range(size):
        row = []
        for j in range(size):
            meets = [pe_meet_cycle(i, j, k) for k in range(size)]
            row.append(f"({','.join(map(str, meets))})")
        lines.append(f"  PE row {i}: " + "  ".join(row))

    return "\n".join(lines)


def format_mesh_wave(
    size: int,
    cycle: int,
    a: list[list[int]],
    b: list[list[int]],
) -> str:
    """Show which MAC products fire at `cycle` across the mesh."""
    lines = [f"Mesh activity @ cycle {cycle}:"]
    for i in range(size):
        cells = []
        for j in range(size):
            active_k = None
            for k in range(size):
                if pe_meet_cycle(i, j, k) == cycle:
                    active_k = k
                    break
            if active_k is not None:
                prod = a[i][active_k] * b[active_k][j]
                cells.append(f"+{prod:4d}")
            else:
                cells.append("  -- ")
        lines.append("  " + " ".join(cells))
    return "\n".join(lines)


class SystolicModel:
    """Cycle-accurate model matching systolic_gemm RTL schedule."""

    def __init__(self, *, size: int = 8, width: int = 16, acc_w: int = 48) -> None:
        self.size = size
        self.width = width
        self.acc_w = acc_w
        self.run_len = 3 * size - 1
        self.slice_len = ws_slice_len(size)

    def run(
        self,
        a: list[list[int]],
        b: list[list[int]],
        *,
        mode: DataflowMode = DataflowMode.OUTPUT_STATIONARY,
    ) -> list[list[int]]:
        if mode == DataflowMode.OUTPUT_STATIONARY:
            return self._run_output_stationary(a, b)
        if mode == DataflowMode.WEIGHT_STATIONARY:
            return self._run_weight_stationary(a, b)
        raise ValueError(f"Unsupported dataflow mode: {mode}")

    def _run_output_stationary(
        self,
        a: list[list[int]],
        b: list[list[int]],
    ) -> list[list[int]]:
        size = self.size
        acc = [[0] * size for _ in range(size)]
        a_out = [[0] * size for _ in range(size)]
        b_out = [[0] * size for _ in range(size)]
        a_vout = [[False] * size for _ in range(size)]
        b_vout = [[False] * size for _ in range(size)]

        for tick in range(self.run_len + 1):
            a_left = [0] * size
            a_valid = [False] * size
            b_top = [0] * size
            b_valid = [False] * size

            for k in range(size):
                for i in range(size):
                    if tick == i + k:
                        a_left[i] = a[i][k]
                        a_valid[i] = True
                for j in range(size):
                    if tick == j + k:
                        b_top[j] = b[k][j]
                        b_valid[j] = True

            next_acc = [row[:] for row in acc]
            next_a_out = [[0] * size for _ in range(size)]
            next_b_out = [[0] * size for _ in range(size)]
            next_a_vout = [[False] * size for _ in range(size)]
            next_b_vout = [[False] * size for _ in range(size)]

            for i in range(size):
                for j in range(size):
                    if j == 0:
                        a_in, av = a_left[i], a_valid[i]
                    else:
                        a_in, av = a_out[i][j - 1], a_vout[i][j - 1]

                    if i == 0:
                        b_in, bv = b_top[j], b_valid[j]
                    else:
                        b_in, bv = b_out[i - 1][j], b_vout[i - 1][j]

                    if av and bv:
                        prod = _to_signed(a_in * b_in, 2 * self.width)
                        next_acc[i][j] = _to_signed(acc[i][j] + prod, self.acc_w)

                    next_a_out[i][j] = a_in
                    next_b_out[i][j] = b_in
                    next_a_vout[i][j] = av
                    next_b_vout[i][j] = bv

            acc = next_acc
            a_out = next_a_out
            b_out = next_b_out
            a_vout = next_a_vout
            b_vout = next_b_vout

        return acc

    def _run_weight_stationary(
        self,
        a: list[list[int]],
        b: list[list[int]],
    ) -> list[list[int]]:
        """K-step WS: for each k, preload B[k][:] then stream A[:][k] with fixed weights."""
        size = self.size
        acc = [[0] * size for _ in range(size)]
        weight = [[0] * size for _ in range(size)]
        weight_valid = [[False] * size for _ in range(size)]

        for k in range(size):
            a_out = [[0] * size for _ in range(size)]
            b_out = [[0] * size for _ in range(size)]
            a_vout = [[False] * size for _ in range(size)]
            b_vout = [[False] * size for _ in range(size)]

            for tick in range(self.slice_len + 1):
                b_top = [0] * size
                b_valid = [False] * size
                for j in range(size):
                    if tick == j:
                        b_top[j] = b[k][j]
                        b_valid[j] = True

                next_weight = [row[:] for row in weight]
                next_wvalid = [row[:] for row in weight_valid]
                next_b_out = [[0] * size for _ in range(size)]
                next_b_vout = [[False] * size for _ in range(size)]

                for i in range(size):
                    for j in range(size):
                        if i == 0:
                            b_in, bv = b_top[j], b_valid[j]
                        else:
                            b_in, bv = b_out[i - 1][j], b_vout[i - 1][j]

                        if bv:
                            next_weight[i][j] = b_in
                            next_wvalid[i][j] = True

                        next_b_out[i][j] = b_in
                        next_b_vout[i][j] = bv

                weight = next_weight
                weight_valid = next_wvalid
                b_out = next_b_out
                b_vout = next_b_vout

            for tick in range(self.slice_len + 1):
                a_left = [0] * size
                a_valid = [False] * size
                for i in range(size):
                    if tick == i:
                        a_left[i] = a[i][k]
                        a_valid[i] = True

                next_acc = [row[:] for row in acc]
                next_a_out = [[0] * size for _ in range(size)]
                next_a_vout = [[False] * size for _ in range(size)]

                for i in range(size):
                    for j in range(size):
                        if j == 0:
                            a_in, av = a_left[i], a_valid[i]
                        else:
                            a_in, av = a_out[i][j - 1], a_vout[i][j - 1]

                        if av and weight_valid[i][j]:
                            prod = _to_signed(a_in * weight[i][j], 2 * self.width)
                            next_acc[i][j] = _to_signed(acc[i][j] + prod, self.acc_w)

                        next_a_out[i][j] = a_in
                        next_a_vout[i][j] = av

                acc = next_acc
                a_out = next_a_out
                a_vout = next_a_vout

        return acc


def _to_signed(value: int, bit_width: int) -> int:
    value &= (1 << bit_width) - 1
    if value >= (1 << (bit_width - 1)):
        return value - (1 << bit_width)
    return value


def test_4x4_matmul_matches_numpy_style():
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
