#!/usr/bin/env python3
"""EVERBLOOM E19: deterministic original leaf-card PBR texture authoring.
Stdlib only. Generated maps are candidate art, not production-approved foliage.
Run: python3 docs/innovation/emergence/visual_quality/make_leaf_maps.py OUTPUT_DIR
"""
import math
import pathlib
import struct
import sys
import zlib

SIZE = 256

def png(path, pixels, channels):
    assert len(pixels) == SIZE * SIZE * channels
    color_type = {1: 0, 3: 2, 4: 6}[channels]
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    raw = b"".join(b"\x00" + pixels[y * SIZE * channels:(y + 1) * SIZE * channels] for y in range(SIZE))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", SIZE, SIZE, 8, color_type, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))

def clamp(x):
    return max(0, min(255, int(round(x))))

def leaf(u, v):
    # UV.y=0 is the anchored stem. Pointed apex, asymmetrical botanical outline.
    center = 0.5 + 0.045 * math.sin(v * math.pi) + 0.018 * v
    width = 0.39 * max(0, math.sin(math.pi * max(0, min(1, v)))) ** 0.76
    d = abs(u - center) / max(0.0001, width)
    # deterministic scalloping is limited to the edge, not arbitrary noise
    edge = 1.0 + 0.025 * math.sin(v * 37.0) + 0.012 * math.sin(v * 79.0)
    inside = d <= edge and 0.035 <= v <= 0.975
    vein = abs(u - center)
    midrib = math.exp(-((vein / 0.012) ** 2))
    # diagonal secondary venation, mirrored on both sides of the midrib
    secondary = math.exp(-((math.sin((v - vein * 1.85) * 54.0) / 0.12) ** 2)) * min(1.0, vein * 9.0)
    return inside, midrib, secondary, d, center

def render():
    albedo = bytearray()
    normal = bytearray()
    roughness = bytearray()
    for y in range(SIZE):
        v = 1.0 - (y + 0.5) / SIZE
        for x in range(SIZE):
            u = (x + 0.5) / SIZE
            inside, midrib, secondary, d, center = leaf(u, v)
            pigment = 0.55 + 0.23 * math.sin(13.0 * v + 7.0 * u) ** 2
            vein_light = 27.0 * midrib + 13.0 * secondary
            margin = max(0.0, (d - 0.70) / 0.30)
            albedo.extend((clamp(39 + 29 * pigment + vein_light - 10 * margin),
                           clamp(86 + 65 * pigment + vein_light - 20 * margin),
                           clamp(26 + 22 * pigment + 0.5 * vein_light),
                           255 if inside else 0))
            # Tangent-space perturbation: analytic center ridge and secondary veins.
            ridge = (u - center) * math.exp(-(((u - center) / 0.045) ** 2))
            nx = -ridge * 5.5
            ny = 0.07 * math.sin(54.0 * (v - abs(u - center) * 1.85)) * secondary
            nz = 1.0 / math.sqrt(1.0 + nx * nx + ny * ny)
            normal.extend((clamp(127.5 + 127.5 * nx * nz),
                           clamp(127.5 + 127.5 * ny * nz),
                           clamp(127.5 + 127.5 * nz)))
            roughness.append(clamp(183 + 21 * margin - 18 * midrib + 9 * secondary))
    return bytes(albedo), bytes(normal), bytes(roughness)

def main():
    if len(sys.argv) != 2:
        raise SystemExit("usage: make_leaf_maps.py OUTPUT_DIR")
    out = pathlib.Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    maps = render()
    names = ("leaf_albedo_rgba.png", "leaf_normal_rgb.png", "leaf_roughness_gray.png")
    for name, data, channels in zip(names, maps, (4, 3, 1)):
        png(out / name, data, channels)
    # Idempotence and expected PNG signatures: deterministic output is byte-for-byte.
    assert render() == maps
    for name in names:
        assert (out / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
    print("PASS original 256px leaf albedo/normal/roughness maps; deterministic regeneration")

if __name__ == "__main__":
    main()
