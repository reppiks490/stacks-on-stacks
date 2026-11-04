"""Fail-closed source audit for the *ordinary* Everbloom launch path.

Run: python tools/principal_launch_quality_gate.py
This is NOT a substitute for native Godot or visual acceptance.
"""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]


def check() -> list[str]:
    failures: list[str] = []
    project = (ROOT / "project.godot").read_text(encoding="utf-8")
    match = re.search(r'^run/main_scene="res://([^"]+)"', project, re.M)
    if not match:
        return ["project.godot has no explicit main scene"]
    scene = ROOT / match.group(1)
    if not scene.is_file():
        return [f"launch scene missing: {scene.relative_to(ROOT)}"]
    scene_text = scene.read_text(encoding="utf-8")
    if 'res://scripts/game.gd' not in scene_text:
        return ["launch scene does not expose expected gameplay orchestrator; manual audit required"]
    game = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
    farmer = (ROOT / "scripts/farmer.gd").read_text(encoding="utf-8")
    valley = (ROOT / "scripts/valley.gd").read_text(encoding="utf-8")
    if 'res://scripts/farmer.gd' not in game:
        failures.append("cannot trace actual spawned hero script; inspect launch integration")
    if any(token in farmer for token in ("CapsuleMesh.new()", "SphereMesh.new()", "CylinderMesh.new()")):
        failures.append("hero still visibly assembled from primitive meshes; authored rig not integrated")
    if not any(token in farmer for token in ("Skeleton3D", "AnimationTree", "AnimationPlayer")):
        failures.append("hero lacks a detectable rig/animation integration")
    house = valley.split("func _house(", 1)
    if len(house) != 2:
        failures.append("house construction not found; manually audit solid geometry")
    else:
        house_body = house[1].split("\nfunc ", 1)[0]
        if not any(token in house_body for token in ("StaticBody3D", "CollisionShape3D", "create_trimesh_collision", "create_convex_collision", "_solid_")):
            failures.append("house construction has no detectable physics collider")
    if 'Vector3(145, 1, 145)' in valley and not any(
        token in game + valley for token in ("ChunkStreamer", "chunk_stream", "load_chunk", "stream_chunks")
    ):
        failures.append("launch world appears limited to 145m ground; 4.8km streaming not detectable")
    return failures


if __name__ == "__main__":
    problems = check()
    if problems:
        print("EVERBLOOM LAUNCH QUALITY GATE: FAIL")
        for problem in problems:
            print(f" - {problem}")
        sys.exit(1)
    print("EVERBLOOM SOURCE PRECHECK: PASS (native/visual/physics gates STILL REQUIRED)")
