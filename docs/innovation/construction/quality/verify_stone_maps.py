#!/usr/bin/env python3
"""Offline deterministic acceptance for original stone texture generator."""
import hashlib
import pathlib
import struct
import tempfile
import zlib
from make_stone_maps import generate


def decode_png(path):
    data = path.read_bytes()
    assert data.startswith(b'\x89PNG\r\n\x1a\n')
    pos, compressed, dimensions = 8, bytearray(), None
    while pos < len(data):
        length = struct.unpack('!I', data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        crc = struct.unpack('!I', data[pos + 8 + length:pos + 12 + length])[0]
        assert zlib.crc32(kind + body) & 0xffffffff == crc
        if kind == b'IHDR':
            dimensions = struct.unpack('!II', body[:8])
            assert body[8:13] == bytes((8, 2, 0, 0, 0))
        elif kind == b'IDAT':
            compressed.extend(body)
        pos += 12 + length
    width, height = dimensions
    rows = zlib.decompress(compressed)
    assert len(rows) == height * (1 + width * 3)
    assert all(rows[y * (1 + width * 3)] == 0 for y in range(height))
    return width, height, [rows[y * (1 + width * 3) + 1:(y + 1) * (1 + width * 3)] for y in range(height)]


def main():
    with tempfile.TemporaryDirectory() as tmp:
        root = pathlib.Path(tmp)
        first = generate(root / 'a', 64)
        second = generate(root / 'b', 64)
        assert len(first) == len(second) == 3
        for a, b in zip(first, second):
            assert hashlib.sha256(a.read_bytes()).digest() == hashlib.sha256(b.read_bytes()).digest()
            w, h, rows = decode_png(a)
            assert (w, h) == (64, 64)
            assert len(set(rows[0])) > 1
        _, _, normals = decode_png(first[1])
        for row in normals:
            for x in range(0, len(row), 3):
                nx, ny, nz = [(row[x + i] / 127.5 - 1) for i in range(3)]
                assert abs(nx * nx + ny * ny + nz * nz - 1) < .025
                assert nz > .1
        _, _, rough = decode_png(first[2])
        assert all(row[x] == row[x + 1] == row[x + 2] for row in rough for x in range(0, len(row), 3))
        for invalid in (0, 31, 65, 2048):
            try:
                generate(root / 'invalid', invalid)
            except ValueError:
                pass
            else:
                raise AssertionError(f'accepted invalid size {invalid}')
    print('PASS: original stone PBR PNG integrity, determinism, normal lengths and rejection')


if __name__ == '__main__':
    main()
