#!/usr/bin/env python3
"""B16: verify periodic PBR seams and normal/height coherence, not rendered quality."""
import pathlib
import tempfile

from make_stone_maps import generate, _height
from verify_stone_maps import decode_png


def main():
    with tempfile.TemporaryDirectory(prefix="everbloom_stone_seams_") as directory:
        for size in (32, 64, 128):
            albedo, normal, roughness = generate(pathlib.Path(directory) / str(size), size)
            maps = [decode_png(p)[2] for p in (albedo, normal, roughness)]
            # Boundary samples are adjacent texels, not identical texels.
            # Their seam deltas should resemble typical interior adjacent deltas.
            for channel, rows in enumerate(maps):
                for axis in ("x", "y"):
                    seam, interior = [], []
                    for i in range(size):
                        if axis == "x":
                            a, b = rows[i][-3:], rows[i][:3]
                            c, d = rows[i][(size // 2 - 1) * 3:(size // 2) * 3], rows[i][(size // 2) * 3:(size // 2 + 1) * 3]
                        else:
                            a, b = rows[-1][i * 3:i * 3 + 3], rows[0][i * 3:i * 3 + 3]
                            c, d = rows[size // 2 - 1][i * 3:i * 3 + 3], rows[size // 2][i * 3:i * 3 + 3]
                        seam.append(max(abs(x - y) for x, y in zip(a, b)))
                        interior.append(max(abs(x - y) for x, y in zip(c, d)))
                    # Large isolated discontinuities are visible as tiling seams.
                    assert max(seam) < 100, (size, channel, axis, max(seam))
                    assert sum(seam) / size < 3 * (sum(interior) / size + 1), (size, channel, axis)
            # Tangent-space normal XY should oppose the gradient of the same
            # relief (base stone plus high-frequency grain), including wrapping.
            nrows = maps[1]
            for y in range(0, size, 3):
                for x in range(0, size, 3):
                    def relief(px, py):
                        return _height(px % size, py % size, size) + (
                            _height((px * 11) % size, (py * 11) % size, size) - .5
                        ) * (13.0 / 64.0)
                    dx = relief(x + 1, y) - relief(x - 1, y)
                    dy = relief(x, y + 1) - relief(x, y - 1)
                    nx, ny = (nrows[y][x * 3 + i] / 127.5 - 1 for i in (0, 1))
                    if abs(dx) > .005:
                        assert nx * dx <= .004, (size, x, y, "x", nx, dx)
                    if abs(dy) > .005:
                        assert ny * dy <= .004, (size, x, y, "y", ny, dy)
            print(f"PASS: {size} PBR seam continuity and normal relief coherence")


if __name__ == "__main__":
    main()
