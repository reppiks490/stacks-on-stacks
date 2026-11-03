#!/usr/bin/env python3
"""EVERBLOOM E19: offline, rights-clean foliage mesh/material contract regression.

Run from repository root:
    python3 docs/innovation/emergence/visual_quality/verify_leaf_asset.py

This checks authored source geometry against the actual generated albedo/normal/
roughness pixels. It is NOT a substitute for Godot import or rendered evidence.
"""
from __future__ import annotations

import hashlib
import importlib.util
import math
from pathlib import Path
import struct
import zlib

HERE = Path(__file__).resolve().parent
OBJ = HERE / "original_curved_leaf_blade.obj"
GENERATOR = HERE / "make_leaf_maps.py"
SHADER = HERE / "foliage_pbr_bound.gdshader"


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def load_generator():
    spec = importlib.util.spec_from_file_location("everbloom_leaf_maps", GENERATOR)
    require(spec is not None and spec.loader is not None, "missing generator")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def parse_obj():
    vertices, uvs, faces = [], [], []
    for raw in OBJ.read_text(encoding="utf-8").splitlines():
        parts = raw.split()
        if not parts or parts[0].startswith("#"):
            continue
        if parts[0] == "v":
            vertices.append(tuple(map(float, parts[1:4])))
        elif parts[0] == "vt":
            uvs.append(tuple(map(float, parts[1:3])))
        elif parts[0] == "f":
            require(len(parts) == 4, "leaf must use triangulated faces")
            face = []
            for ref in parts[1:]:
                fields = ref.split("/")
                require(len(fields) >= 2 and fields[1], "missing UV reference")
                vi, ti = int(fields[0]) - 1, int(fields[1]) - 1
                face.append((vi, ti))
            faces.append(face)
    require(len(vertices) >= 9 and len(faces) >= 8, "leaf geometry incomplete")
    require(len(uvs) >= 9, "missing authored UVs")
    for face in faces:
        for vi, ti in face:
            require(0 <= vi < len(vertices) and 0 <= ti < len(uvs), "invalid OBJ index")
        a, b, c = (vertices[vi] for vi, _ in face)
        ab = tuple(b[i] - a[i] for i in range(3))
        ac = tuple(c[i] - a[i] for i in range(3))
        cross = (ab[1]*ac[2]-ab[2]*ac[1], ab[2]*ac[0]-ab[0]*ac[2], ab[0]*ac[1]-ab[1]*ac[0])
        require(sum(t*t for t in cross) > 1e-13, "degenerate mesh triangle")
        ta, tb, tc = (uvs[ti] for _, ti in face)
        area = (tb[0]-ta[0])*(tc[1]-ta[1])-(tc[0]-ta[0])*(tb[1]-ta[1])
        require(abs(area) > 1e-8, "degenerate UV triangle")
    require(all(0 <= t <= 1 for uv in uvs for t in uv), "UV outside texture")
    require(min(v[1] for v in vertices) >= -1e-6, "stem must be at y=0")
    require(max(v[1] for v in vertices) > 0.3, "blade scale unexpectedly small")
    return vertices, uvs, faces


def verify():
    vertices, uvs, faces = parse_obj()
    maps = load_generator()
    albedo, normal, roughness = maps.render()
    size = maps.SIZE
    require(len(albedo) == size*size*4, "invalid albedo dimensions")
    require(len(normal) == size*size*3, "invalid normal dimensions")
    require(len(roughness) == size*size, "invalid roughness dimensions")
    require(maps.render() == (albedo, normal, roughness), "nondeterministic texture generation")
    shader = SHADER.read_text(encoding="utf-8")
    for name in ("leaf_albedo", "leaf_normal", "leaf_roughness", "reduced_motion", "ALPHA_SCISSOR_THRESHOLD"):
        require(name in shader, "shader contract missing " + name)
    require("UV.y" in shader, "missing stem-anchored wind contract")
    opaque = sum(albedo[i] > 0 for i in range(3, len(albedo), 4))
    require(size*size*0.15 < opaque < size*size*0.8, "implausible alpha silhouette coverage")
    # A UV triangle must overlap the actual painted blade, not only transparent atlas space.
    covered = 0
    for face in faces:
        points = [uvs[ti] for _, ti in face]
        for weights in ((1/3,1/3,1/3), (0.6,0.2,0.2), (0.2,0.6,0.2), (0.2,0.2,0.6)):
            u = sum(p[0]*w for p,w in zip(points, weights))
            v = sum(p[1]*w for p,w in zip(points, weights))
            x = min(size-1, max(0, int(u*size)))
            y = min(size-1, max(0, int((1-v)*size)))
            covered += albedo[(y*size+x)*4+3] > 0
    require(covered >= len(faces), "mesh UVs do not cover enough painted leaf")
    # Dense barycentric sampling prevents large transparent UV wedges from
    # passing the sparse four-point test. Measure actual generated alpha.
    dense_hits = 0
    dense_samples = 0
    for face in faces:
        points = [uvs[ti] for _, ti in face]
        for i in range(13):
            for j in range(13 - i):
                weights = (i / 12.0, j / 12.0, 1.0 - (i + j) / 12.0)
                u = sum(p[0] * w for p, w in zip(points, weights))
                v = sum(p[1] * w for p, w in zip(points, weights))
                x = min(size - 1, max(0, int(u * size)))
                y = min(size - 1, max(0, int((1.0 - v) * size)))
                dense_hits += int(albedo[(y * size + x) * 4 + 3] > 0)
                dense_samples += 1
    require(dense_hits / dense_samples >= 0.75,
            f"leaf mesh/painted silhouette mismatch: {dense_hits}/{dense_samples}")
    print(f"Leaf UV alpha overlap: {dense_hits}/{dense_samples} = {dense_hits / dense_samples:.1%}")
    for i in range(0, len(normal), 3):
        x, y, z = ((normal[i+j]/255.0)*2-1 for j in range(3))
        require(z > 0.35, "normal map points away from leaf surface")
        require(0.90 <= math.sqrt(x*x+y*y+z*z) <= 1.10, "non-unit tangent normal")
    require(min(roughness) >= 0 and max(roughness) <= 255, "roughness outside 8-bit range")
    print("PASS E19 leaf source geometry/UV, alpha overlap, 3 PBR maps, normal lengths, deterministic generator")
    print("SHA256 albedo", hashlib.sha256(albedo).hexdigest())
    print("SHA256 normal", hashlib.sha256(normal).hexdigest())
    print("SHA256 roughness", hashlib.sha256(roughness).hexdigest())
    print("LIMITATION: Godot import, shader compile, visual quality, FPS and gameplay remain UNVERIFIED")


if __name__ == "__main__":
    verify()
