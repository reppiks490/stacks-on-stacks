#!/usr/bin/env python3
"""Independent multiresolution smoke test for the original stone material maps.

Checks actual generated PNG bytes at three power-of-two sizes; does not imply
Godot shader, rendered quality, or desktop performance acceptance.
"""
import hashlib
import pathlib
import tempfile

from make_stone_maps import generate
from verify_stone_maps import decode_png


def check_size(root, size):
    outputs = generate(root / f"first_{size}", size)
    repeated = generate(root / f"repeat_{size}", size)
    assert [p.name for p in outputs] == [
        "stone_albedo.png", "stone_normal.png", "stone_roughness.png"
    ]
    for first, second in zip(outputs, repeated):
        assert first.is_file() and second.is_file()
        assert hashlib.sha256(first.read_bytes()).digest() == hashlib.sha256(second.read_bytes()).digest()
        width, height, rows = decode_png(first)
        assert (width, height) == (size, size)
        assert len(rows) == size and all(len(row) == size * 3 for row in rows)
    _, _, colors = decode_png(outputs[0])
    _, _, normals = decode_png(outputs[1])
    _, _, roughness = decode_png(outputs[2])
    assert len({tuple(row[x:x + 3]) for row in colors for x in range(0, len(row), 3)}) > 8
    for y in range(size):
        for x in range(size):
            offset = x * 3
            rgb = normals[y][offset:offset + 3]
            n = [(component / 127.5) - 1 for component in rgb]
            assert abs(sum(component * component for component in n) - 1.0) < .03
            assert n[2] > 0
            r, g, b = roughness[y][offset:offset + 3]
            assert r == g == b
            assert 0 < r < 255
    print(f"PASS: {size}x{size} original stone albedo/normal/roughness deterministic PNG")


def main():
    with tempfile.TemporaryDirectory(prefix="everbloom_stone_multires_") as temp:
        for size in (32, 64, 128):
            check_size(pathlib.Path(temp), size)


if __name__ == "__main__":
    main()
