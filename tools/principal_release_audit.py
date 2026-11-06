#!/usr/bin/env python3
"""Fail-closed source audit for the actual Godot launch path; no rendering claims."""
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
errors = []
def require(condition, message):
    if not condition:
        errors.append(message)

project = (ROOT / "project.godot").read_text(encoding="utf-8")
match = re.search(r'^run/main_scene="res://([^"]+)"', project, re.M)
require(match is not None, "No explicit launch scene")
scene = ROOT / match.group(1) if match else None
require(scene is not None and scene.is_file(), "Launch scene missing")
if scene and scene.is_file():
    scene_text = scene.read_text(encoding="utf-8")
    scripts = re.findall(r'path="res://([^"]+\\.gd)"', scene_text)
    require(bool(scripts), "Launch scene has no script")
    for script in scripts:
        require((ROOT / script).is_file(), f"Missing launch script: {script}")
farmer = ROOT / "scripts/farmer.gd"
require(farmer.is_file(), "Missing playable character controller")
if farmer.is_file():
    text = farmer.read_text(encoding="utf-8")
    require("CharacterBody3D" in text and "move_and_slide()" in text, "Missing physics controller")
    primitives = ("CapsuleMesh.new()", "SphereMesh.new()", "CylinderMesh.new()")
    require(not any(p in text for p in primitives), "RELEASE BLOCKER: player still assembled from primitive meshes")
    require("Skeleton3D" in text or ".glb" in text or ".gltf" in text, "RELEASE BLOCKER: no authored skinned player asset reference")
require((ROOT / "tests/principal_live_collision_smoke.gd").is_file(),
        "RELEASE BLOCKER: native live collision regression absent from this branch")
print("Everbloom launch-source quality audit")
for error in errors:
    print("FAIL:", error)
if errors:
    print(f"BLOCKED: {len(errors)} gate(s); this is source inspection, not a native/render test.")
    sys.exit(1)
print("PASS: source-only checks. Native 120-frame traversal, saves, visuals and FPS still required.")
