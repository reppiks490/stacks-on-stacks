#!/usr/bin/env python3
"""E19: offline acceptance for the original Godot leaf candidate staging contract.

Run: python3 docs/innovation/emergence/visual_quality/verify_leaf_staging.py
This is NOT a substitute for Godot import, screenshots or FPS measurement.
"""
from __future__ import annotations

import hashlib
import importlib.util
from pathlib import Path
import tempfile

HERE = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("leaf_stage", HERE / "stage_leaf_scene.py")
assert spec and spec.loader
stage_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(stage_module)


def verify() -> None:
    with tempfile.TemporaryDirectory(prefix="everbloom-leaf-") as temporary:
        root = Path(temporary)
        destination = root / "everbloom_leaf_candidate"
        stage_module.stage(destination)
        invalid_destination = root / "wrong_leaf_directory"
        try:
            stage_module.stage(invalid_destination)
        except ValueError:
            assert not invalid_destination.exists(), "Invalid staging must not leave files behind"
        else:
            raise AssertionError("Mismatched destination must be rejected")
        expected = {
            "original_curved_leaf_blade.obj",
            "foliage_pbr_bound.gdshader",
            "leaf_albedo_rgba.png",
            "leaf_normal_rgb.png",
            "leaf_roughness_gray.png",
            "leaf_material.tres",
            "leaf_candidate.tscn",
        }
        assert {p.name for p in destination.iterdir()} == expected | {"SHA256SUMS.txt"}
        for name in ("leaf_albedo_rgba.png", "leaf_normal_rgb.png", "leaf_roughness_gray.png"):
            assert (destination / name).read_bytes().startswith(b"\x89PNG\r\n\x1a\n")
        material = (destination / "leaf_material.tres").read_text()
        scene = (destination / "leaf_candidate.tscn").read_text()
        shader = (destination / "foliage_pbr_bound.gdshader").read_text()
        for parameter in ("leaf_albedo", "leaf_normal", "leaf_roughness"):
            assert "shader_parameter/" + parameter in material
            assert "uniform sampler2D " + parameter in shader
        assert 'type="Mesh"' in scene
        assert 'type="PackedScene"' not in scene
        for name in expected:
            assert (destination / name).stat().st_size > 0
        for line in (destination / "SHA256SUMS.txt").read_text().splitlines():
            digest, name = line.split("  ", 1)
            assert digest == hashlib.sha256((destination / name).read_bytes()).hexdigest()
        try:
            stage_module.stage(destination)
        except FileExistsError:
            pass
        else:
            raise AssertionError("Existing candidate output must not be overwritten")
        print("PASS E19 staging: PBR bindings, OBJ mesh contract, path guard, hashes, no overwrite")
        print("UNVERIFIED: Godot import, shader compilation, visual fidelity, FPS")


if __name__ == "__main__":
    verify()
