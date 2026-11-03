#!/usr/bin/env python3
"""B16: verify that stone normal-map pixels encode the authored relief gradient.

Offline regression for the existing original material candidate. No rendering
or production-quality claim. Run alongside verify_stone_maps.py.
"""
import math
import pathlib
import tempfile

from make_stone_maps import _height, generate
from verify_stone_maps import decode_png


def expected_normal(x, y, size):
    def relief(px, py):
        px %= size
        py %= size
        coarse = _height(px, py, size)
        grain = _height((px * 11) % size, (py * 11) % size, size) - 0.5
        return coarse + grain * (13.0 / 64.0)

    dx = (relief(x + 1, y) - relief(x - 1, y)) * 4.0
    dy = (relief(x, y + 1) - relief(x, y - 1)) * 4.0
    length = math.sqrt(dx * dx + dy * dy + 1.0)
    return (-dx / length, -dy / length, 1.0 / length)


def main():
    size = 64
    with tempfile.TemporaryDirectory() as temporary:
        maps = generate(pathlib.Path(temporary) / "stone", size)
        _, _, normals = decode_png(maps[1])
        _, _, albedo = decode_png(maps[0])
        _, _, roughness = decode_png(maps[2])
        assert len(normals) == len(albedo) == len(roughness) == size
        for y in range(size):
            for x in range(size):
                index = x * 3
                encoded = normals[y][index:index + 3]
                actual = tuple(value / 127.5 - 1.0 for value in encoded)
                expected = expected_normal(x, y, size)
                # One 8-bit channel step plus rounding tolerance.
                assert max(abs(a - b) for a, b in zip(actual, expected)) < 0.009, (x, y)
                assert actual[2] > 0
                assert all(0 <= channel <= 255 for channel in albedo[y][index:index + 3])
                assert roughness[y][index] == roughness[y][index + 1] == roughness[y][index + 2]
    print("PASS: 4096 authored-relief / encoded-normal pixel comparisons")


if __name__ == "__main__":
    main()
