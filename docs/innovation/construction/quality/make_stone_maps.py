#!/usr/bin/env python3
"""Original deterministic stone material maps for EVERBLOOM's existing arch.

No external assets or dependencies. Generates tileable PNG albedo, tangent-space
normal, and roughness. This is a material prototype, not finished authored art.
"""
import argparse
import math
import pathlib
import struct
import zlib


def _noise(x, y, seed):
    n = ((x * 374761393) ^ (y * 668265263) ^ (seed * 2246822519)) & 0xffffffff
    n = ((n ^ (n >> 13)) * 1274126177) & 0xffffffff
    return ((n ^ (n >> 16)) & 0xffff) / 65535.0


def _height(x, y, size):
    # Periodic multi-octave field: edges agree across tile boundaries.
    h = 0.0
    for cells, weight, seed in ((4, .45, 7), (12, .30, 19), (32, .17, 41), (64, .08, 83)):
        u, v = x * cells / size, y * cells / size
        ix, iy = math.floor(u), math.floor(v)
        fx, fy = u - ix, v - iy
        fx, fy = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy)
        def sample(dx, dy):
            return _noise((ix + dx) % cells, (iy + dy) % cells, seed)
        a = sample(0, 0) * (1 - fx) + sample(1, 0) * fx
        b = sample(0, 1) * (1 - fx) + sample(1, 1) * fx
        h += weight * (a * (1 - fy) + b * fy)
    return h


def _png(path, size, pixels):
    raw = b''.join(b'\x00' + bytes(pixels[y * size:(y + 1) * size]) for y in range(size))
    def chunk(kind, data):
        return struct.pack('!I', len(data)) + kind + data + struct.pack('!I', zlib.crc32(kind + data) & 0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('!2I5B', size, size, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def generate(destination, size=256):
    if size < 32 or size > 1024 or size & (size - 1):
        raise ValueError('size must be a power of two between 32 and 1024')
    destination = pathlib.Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    field = [[_height(x, y, size) for x in range(size)] for y in range(size)]
    albedo, normal, roughness = [], [], []
    for y in range(size):
        ar, nr, rr = bytearray(), bytearray(), bytearray()
        for x in range(size):
            h = field[y][x]
            grain = _noise(x, y, 109) - .5
            tint = (h - .5) * 64 + grain * 13
            ar.extend(max(0, min(255, round(base + tint))) for base in (159, 148, 132))
            dx = (field[y][(x + 1) % size] - field[y][(x - 1) % size]) * 4
            dy = (field[(y + 1) % size][x] - field[(y - 1) % size][x]) * 4
            length = math.sqrt(dx * dx + dy * dy + 1)
            nr.extend(round(127.5 * (v / length + 1)) for v in (-dx, -dy, 1))
            r = max(0, min(255, round(192 + (h - .5) * 45 + grain * 17)))
            rr.extend((r, r, r))
        albedo.append(ar)
        normal.append(nr)
        roughness.append(rr)
    paths = []
    for name, rows in (('stone_albedo.png', albedo), ('stone_normal.png', normal), ('stone_roughness.png', roughness)):
        path = destination / name
        _png(path, size, rows)
        paths.append(path)
    return paths


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=pathlib.Path)
    parser.add_argument('--size', type=int, default=256)
    args = parser.parse_args()
    for path in generate(args.output, args.size):
        print(path)
