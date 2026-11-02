#!/usr/bin/env python3
"""Generate SABLESTAR original low-poly source meshes and synthesized audio.

100% deterministic; Python standard library; no ripped game files or addons.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]


def prism(vertices: list[tuple[float, float, float]], width: float, z_depth: float):
    """Extrude ordered closed XY polygon into a two-sided triangular prism."""
    n = len(vertices)
    pts = [(x, y, z_depth) for x, y, _ in vertices] + [(x, y, z_depth - width) for x, y, _ in vertices]
    faces = []
    for i in range(1, n - 1):
        faces.append((1, i + 1, i + 2))
        faces.append((n + 1, n + i + 2, n + i + 1))
    for i in range(n):
        j = (i + 1) % n
        faces.extend(((i + 1, j + 1, n + i + 1), (j + 1, n + j + 1, n + i + 1)))
    return pts, faces


def mesh_source() -> str:
    """Distinctive original sabre, split-crescent crossguard and diamond pommel."""
    groups = [
        ("sableblade_main", "violet_steel", [(0.00, 2.8, 0),(-.21, 2.05, 0),(-.28,.95,0),(-.10,.40,0),(.10,.40,0),(.28,.95,0),(.21,2.05,0)], .075,.09),
        ("edge_crimson", "ember_edge", [(-.21,2.05,0),(-.31,1.08,0),(-.29,.88,0),(-.23,.95,0)], .038,.1),
        ("crossguard_left", "dark_iron", [(-.05,.49,0),(-.70,.57,0),(-.84,.83,0),(-.68,.65,0),(-.09,.34,0)], .12,.1),
        ("crossguard_right", "dark_iron", [(.05,.49,0),(.70,.57,0),(.84,.83,0),(.68,.65,0),(.09,.34,0)], .12,.1),
        ("grip", "obsidian", [(-.10,.38,0),(-.10,-.58,0),(.10,-.58,0),(.10,.38,0)], .16,.075),
        ("pommel", "heart_crystal", [(0,-.90,0),(-.16,-.67,0),(0,-.48,0),(.16,-.67,0)], .22,.11),
    ]
    lines = ["# SABLESTAR original sword source mesh; generated without proprietary assets", "mtllib sableblade.mtl", "o Sableblade", "s off"]
    offset = 0
    for name, material, poly, depth, thickness in groups:
        pts, faces = prism(poly, depth, thickness)
        lines.extend(("g " + name, "usemtl " + material))
        lines.extend("v %.5f %.5f %.5f" % v for v in pts)
        lines.extend("f %d %d %d" % tuple(offset + i for i in face) for face in faces)
        offset += len(pts)
    return "\n".join(lines) + "\n"


def material_source() -> str:
    colors = {
        "violet_steel": (0.44, .34, .64),
        "ember_edge": (0.86, .24, .41),
        "dark_iron": (.18, .17, .26),
        "obsidian": (.10, .13, .20),
        "heart_crystal": (.87, .65, .91),
    }
    return "# Original source materials for the Sableblade\n" + "\n".join(
        f"newmtl {name}\nKd {red:.4f} {green:.4f} {blue:.4f}\nKa 0.08 0.08 0.08\nKs 0.3 0.3 0.3\nNs 100.0\n"
        for name,(red,green,blue) in colors.items()
    ) + "\n"


def tone(path: Path, frequencies: tuple[float,...], length: float, seed: int) -> None:
    sample_rate = 22050
    count = int(length * sample_rate)
    amplitude = 11000
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(sample_rate)
        samples = bytearray()
        for sample in range(count):
            seconds = sample / sample_rate
            envelope = min(1.0, seconds * 28.0) * math.exp(-seconds * 4.8)
            signal = 0.0
            for idx, f in enumerate(frequencies):
                vibrato = 1 + .008 * math.sin(seconds * 11.3 + idx + seed)
                signal += math.sin(math.tau * f * vibrato * seconds) / (idx + 1.0)
            signal += .12 * math.sin(math.tau * (122 + seed * 11) * seconds)
            value = int(max(-32000, min(32000, signal * amplitude * envelope)))
            samples.extend(struct.pack("<h", value))
        output.writeframes(bytes(samples))


def generate(root: Path) -> dict:
    models = root / "assets" / "models"
    sounds = root / "assets" / "audio"
    models.mkdir(parents=True, exist_ok=True)
    sounds.mkdir(parents=True, exist_ok=True)
    (models / "sableblade.obj").write_text(mesh_source(), encoding="utf-8")
    (models / "sableblade.mtl").write_text(material_source(), encoding="utf-8")
    tone(sounds / "resonance_pulse.wav", (198, 297, 401, 620), .54, 1)
    tone(sounds / "covenant_seal.wav", (220, 330, 440, 659), .70, 7)
    files = sorted(
        list((root / "assets" / "vector").glob("*.svg"))
        + list(models.glob("*")) + list(sounds.glob("*"))
    )
    entries = [{"path":p.relative_to(root).as_posix(),
                "sha256":hashlib.sha256(p.read_bytes()).hexdigest(),
                "bytes":p.stat().st_size} for p in files]
    manifest = {"schema_version": 1, "game": "SABLESTAR", "origin": "original_work",
                "external_proprietary_assets": 0, "renderer": "Godot 4.x",
                "native_engine_import": "not_run", "asset_entries": entries}
    (root / "assets" / "provenance.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True)+"\n", encoding="utf-8")
    return manifest


def verify(root: Path) -> tuple[bool,list[str]]:
    manifest=json.loads((root / 'assets' / 'provenance.json').read_text())
    errors=[]
    for item in manifest['asset_entries']:
        p=root/item['path']
        if not p.is_file():
            errors.append(f"Missing {item['path']}")
            continue
        if p.stat().st_size != item['bytes'] or hashlib.sha256(p.read_bytes()).hexdigest()!=item['sha256']:
            errors.append(f"Hash/size drift {item['path']}")
        if p.suffix == '.obj':
            source=p.read_text()
            if source.count('\nv ') < 20 or source.count('\nf ') < 20:
                errors.append('Sableblade is not a substantive authored mesh')
        if p.suffix == '.wav':
            with wave.open(str(p),'rb') as sound:
                if sound.getnframes() < 3000 or sound.getnchannels()!=1:
                    errors.append('Malformed original audio '+item['path'])
    return (not errors, errors)

if __name__ == '__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--verify', action='store_true')
    args=parser.parse_args()
    if not args.verify:
        manifest=generate(ROOT)
        print(f"Generated {len(manifest['asset_entries'])} original, hash-tracked source assets")
    ok,issues=verify(ROOT)
    for issue in issues: print('ERROR:',issue)
    if ok: print('PASS: original asset checksums, OBJ, WAV, and artwork inventory')
    raise SystemExit(int(not ok))
