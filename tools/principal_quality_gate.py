#!/usr/bin/env python3
"""Fail-closed static preflight for Everbloom's ordinary Godot launch path.

Run: python tools/principal_quality_gate.py --project /path/to/project
Static PASS is never evidence of native gameplay, visuals, or FPS.
"""
import argparse
import pathlib
import re
import sys


def inspect(root: pathlib.Path):
    failures = []

    def read(path):
        target = root / path
        if not target.is_file():
            failures.append(f"MISSING: {path}")
            return ""
        return target.read_text(encoding="utf-8")

    project = read("project.godot")
    scene_match = re.search(r'^run/main_scene="res://([^"]+)"', project, re.M)
    if not scene_match:
        failures.append("LAUNCH: project.godot lacks run/main_scene")
        return failures
    scene_path = scene_match.group(1)
    scene = read(scene_path)
    game_match = re.search(r'path="res://([^"]*game\.gd)"', scene)
    if not game_match:
        failures.append(f"LAUNCH: {scene_path} does not reference game.gd")
        return failures
    game = read(game_match.group(1))
    farmer = read("scripts/farmer.gd")
    valley = read("scripts/valley.gd")
    if 'res://scripts/farmer.gd' not in game:
        failures.append("HERO: launched game does not instantiate farmer.gd")
    if 'res://scripts/valley.gd' not in game:
        failures.append("WORLD: launched game does not instantiate valley.gd")
    if any(re.search(r'\b' + name + r'\.new\s*\(', farmer)
           for name in ("CapsuleMesh", "SphereMesh", "CylinderMesh", "BoxMesh")):
        failures.append("HERO: primitive mesh character remains in ordinary launch")
    if not re.search(r'AnimationTree|AnimationPlayer|Skeleton3D', farmer):
        failures.append("HERO: no rig/animation binding in launched controller")
    if 'continental_world.gd' not in valley and 'continental_world.gd' not in game:
        failures.append("WORLD: continental streaming not reachable from launch")
    if not re.search(r'CollisionShape3D|CollisionPolygon3D|create_trimesh_collision', valley):
        failures.append("WORLD: no collision generation in launched valley")
    if re.search(r'func _house\(', valley):
        house = valley.split('func _house(', 1)[1].split('\nfunc ', 1)[0]
        if not re.search(r'CollisionShape3D|StaticBody3D|collid', house, re.I):
            failures.append("BUILDINGS: house factory lacks collision")
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project", type=pathlib.Path, default=pathlib.Path("."))
    args = parser.parse_args()
    errors = inspect(args.project)
    for error in errors:
        print("FAIL:", error)
    if errors:
        print(f"BLOCKED: {len(errors)} static launch defects; native Godot evidence required")
        return 1
    print("STATIC PREFLIGHT PASS ONLY; native Godot, physics, visual, save and FPS gates remain")
    return 0


if __name__ == "__main__":
    sys.exit(main())
