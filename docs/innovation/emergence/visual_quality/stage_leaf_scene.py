#!/usr/bin/env python3
"""Stage the existing original leaf mesh, shader and generated PBR maps as a Godot scene.

Run from any directory:
    python3 docs/innovation/emergence/visual_quality/stage_leaf_scene.py OUTPUT_DIR

This creates a *candidate* importable Godot scene, not proof of visual quality.
The output is self-contained and can be copied into a Godot 4.x project.
No third-party assets, network access or installed Python packages required.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
from pathlib import Path
import shutil

HERE = Path(__file__).resolve().parent
FILES = ("original_curved_leaf_blade.obj", "foliage_pbr_bound.gdshader")
MAP_NAMES = ("leaf_albedo_rgba.png", "leaf_normal_rgb.png", "leaf_roughness_gray.png")


def stage(destination: Path) -> None:
    destination = destination.resolve()
    # Never overwrite source art or an existing output directory.
    if destination.exists():
        raise FileExistsError(f"Refusing to overwrite existing destination: {destination}")
    if destination == HERE or HERE in destination.parents:
        raise ValueError("Stage outside the authored source directory")
    spec = importlib.util.spec_from_file_location("everbloom_leaf_maps", HERE / "make_leaf_maps.py")
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load original map generator")
    generator = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(generator)
    destination.mkdir(parents=True)
    for filename in FILES:
        shutil.copyfile(HERE / filename, destination / filename)
    maps = generator.render()
    for filename, pixels, channels in zip(MAP_NAMES, maps, (4, 3, 1)):
        generator.png(destination / filename, pixels, channels)
    # Explicit resource references bind all three maps to the existing shader.
    material = '''[gd_resource type="ShaderMaterial" load_steps=5 format=3]

[ext_resource type="Shader" path="res://%s/foliage_pbr_bound.gdshader" id="1"]
[ext_resource type="Texture2D" path="res://%s/leaf_albedo_rgba.png" id="2"]
[ext_resource type="Texture2D" path="res://%s/leaf_normal_rgb.png" id="3"]
[ext_resource type="Texture2D" path="res://%s/leaf_roughness_gray.png" id="4"]

[resource]
shader = ExtResource("1")
shader_parameter/leaf_albedo = ExtResource("2")
shader_parameter/leaf_normal = ExtResource("3")
shader_parameter/leaf_roughness = ExtResource("4")
shader_parameter/reduced_motion = false
'''
    # The output is intended to be copied to res://everbloom_leaf_candidate.
    prefix = "everbloom_leaf_candidate"
    (destination / "leaf_material.tres").write_text(material % (prefix, prefix, prefix, prefix), encoding="utf-8")
    scene = '''[gd_scene load_steps=3 format=3]

[ext_resource type="PackedScene" path="res://everbloom_leaf_candidate/original_curved_leaf_blade.obj" id="1"]
[ext_resource type="Material" path="res://everbloom_leaf_candidate/leaf_material.tres" id="2"]

[node name="LeafCandidate" type="Node3D"]
[node name="Blade" parent="." instance=ExtResource("1")]
material_override = ExtResource("2")
'''
    # OBJ imports as Mesh rather than PackedScene in Godot. Use MeshInstance3D.
    scene = '''[gd_scene load_steps=3 format=3]

[ext_resource type="ArrayMesh" path="res://everbloom_leaf_candidate/original_curved_leaf_blade.obj" id="1"]
[ext_resource type="Material" path="res://everbloom_leaf_candidate/leaf_material.tres" id="2"]

[node name="LeafCandidate" type="Node3D"]
[node name="Blade" type="MeshInstance3D" parent="."]
mesh = ExtResource("1")
material_override = ExtResource("2")
'''
    (destination / "leaf_candidate.tscn").write_text(scene, encoding="utf-8")
    hashes = "\n".join(
        f"{hashlib.sha256((destination / p).read_bytes()).hexdigest()}  {p}"
        for p in sorted([*FILES, *MAP_NAMES, "leaf_material.tres", "leaf_candidate.tscn"])
    )
    (destination / "SHA256SUMS.txt").write_text(hashes + "\n", encoding="utf-8")
    print(f"Staged original leaf scene at {destination}")
    print("Copy directory to GODOT_PROJECT/everbloom_leaf_candidate and open leaf_candidate.tscn.")
    print("UNVERIFIED: native OBJ import, shader compile, visual quality, animation and FPS.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    stage(args.output_dir)
