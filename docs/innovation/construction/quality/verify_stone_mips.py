#!/usr/bin/env python3
"""B16: test stone PBR mip-chain stability and periodic filtering (offline).

This is a texture-quality gate, NOT a substitute for native Godot renders.
No dependencies beyond Python standard library and the original generator.
"""
import math
import pathlib
import tempfile

from make_stone_maps import generate
from verify_stone_maps import decode_png


def downsample(rows):
    height = len(rows)
    width = len(rows[0]) // 3
    assert height == width and width % 2 == 0
    result = []
    for y in range(0, height, 2):
        row = bytearray()
        for x in range(0, width, 2):
            for c in range(3):
                values = [rows[(y + dy) % height][((x + dx) % width) * 3 + c]
                          for dy in (0, 1) for dx in (0, 1)]
                row.append(round(sum(values) / 4))
        result.append(bytes(row))
    return result


def check_normals(rows, size):
    for row in rows:
        for x in range(size):
            nx, ny, nz = (row[x * 3 + c] / 127.5 - 1 for c in range(3))
            # Averaged normals must be renormalized by the renderer after mip sampling.
            assert all(math.isfinite(v) for v in (nx, ny, nz))
            assert nz > 0.08, (size, x, nz)
            # Linear filtering must not collapse the normal into a near-zero vector.
            assert nx * nx + ny * ny + nz * nz > 0.10, (size, x)


def check_material_detail(rows, size, channel):
    # A successful mip import must not silently erase authored surface variation.
    # At very small mips averaging legitimately removes high-frequency detail.
    if size < 8:
        return
    pixels = [row[i] for row in rows for i in range(0, len(row), 3)]
    contrast = max(pixels) - min(pixels)
    if channel == 0:
        assert contrast >= 2, ("albedo flattened", size, contrast)
    elif channel == 2:
        assert contrast >= 1, ("roughness flattened", size, contrast)


def main():
    with tempfile.TemporaryDirectory(prefix="everbloom_stone_mips_") as tmp:
        for resolution in (64, 128, 256):
            maps = [decode_png(path)[2] for path in generate(pathlib.Path(tmp) / str(resolution), resolution)]
            for channel, original in enumerate(maps):
                rows, size = original, resolution
                while size >= 2:
                    assert len(rows) == size
                    assert all(len(row) == size * 3 for row in rows)
                    check_material_detail(rows, size, channel)
                    if channel == 1:
                        check_normals(rows, size)
                    if channel == 2:
                        assert all(row[i] == row[i + 1] == row[i + 2]
                                   for row in rows for i in range(0, len(row), 3))
                    if size == 2:
                        # Include the final 1x1 mip; its normal must still face outward.
                        rows = downsample(rows)
                        size = 1
                        if channel == 1:
                            check_normals(rows, size)
                        if channel == 2:
                            assert rows[0][0] == rows[0][1] == rows[0][2]
                        break
                    rows = downsample(rows)
                    size //= 2
            print(f"PASS: {resolution}px PBR mip levels remain finite, aligned, and valid")


if __name__ == "__main__":
    main()
