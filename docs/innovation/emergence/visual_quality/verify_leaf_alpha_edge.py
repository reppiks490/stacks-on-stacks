#!/usr/bin/env python3
"""E19 offline leaf silhouette audit: detect geometry outside painted alpha.

This is a conservative pre-import acceptance gate, not rendered evidence.
Run from any directory: python3 verify_leaf_alpha_edge.py
"""
from pathlib import Path
import importlib.util

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("leaf_maps", HERE / "make_leaf_maps.py")
assert spec and spec.loader
maps = importlib.util.module_from_spec(spec)
spec.loader.exec_module(maps)

uvs, faces = [], []
for raw in (HERE / "original_curved_leaf_blade.obj").read_text().splitlines():
    fields = raw.split()
    if not fields:
        continue
    if fields[0] == "vt":
        uvs.append(tuple(map(float, fields[1:3])))
    if fields[0] == "f":
        faces.append([int(v.split("/")[1]) - 1 for v in fields[1:]])
assert uvs and faces, "missing leaf UV geometry"

# Sample all face interiors, not just a few barycentres. A mesh that extends
# far beyond the painted alpha wastes geometry and creates ugly hard cutouts.
painted, transparent = 0, 0
for face in faces:
    assert len(face) == 3
    tri = [uvs[i] for i in face]
    for a in range(1, 10):
        for b in range(1, 11 - a):
            wa, wb = a / 11, b / 11
            wc = 1 - wa - wb
            u = sum(p[0] * w for p, w in zip(tri, (wa, wb, wc)))
            v = sum(p[1] * w for p, w in zip(tri, (wa, wb, wc)))
            if maps.leaf(u, v)[0]:
                painted += 1
            else:
                transparent += 1
assert painted > 0, "all mesh UV faces miss painted silhouette"
total = painted + transparent
coverage = painted / total
print(f"E19 leaf UV painted coverage: {painted}/{total} = {coverage:.1%}")
# Informational until mesh silhouette and texture edge are visually inspected.
# Do not silently claim a high-fidelity asset on numerical coverage alone.
if coverage < 0.50:
    raise SystemExit("FAIL: less than half of sampled leaf mesh is painted")
print("PASS: offline UV alpha coverage floor; native Godot/render/FPS UNVERIFIED")
