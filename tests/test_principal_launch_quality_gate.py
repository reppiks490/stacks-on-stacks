"""Fail-closed static release gate for the ordinary Everbloom launch path.

This does NOT replace native Godot physics, rendering or traversal tests.
Run: python -m unittest tests.test_principal_launch_quality_gate
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[1]


class LaunchQualityGate(unittest.TestCase):
    def read(self, relative):
        return (ROOT / relative).read_text(encoding="utf-8")

    def test_real_launch_scene_contract(self):
        project = self.read("project.godot")
        match = re.search(r'^run/main_scene="([^"]+)"', project, re.M)
        self.assertIsNotNone(match, "No canonical Godot launch scene")
        scene = match.group(1).removeprefix("res://")
        self.assertTrue((ROOT / scene).is_file(), "Launch scene missing")
        self.assertIn("res://scripts/game.gd", self.read(scene))

    def test_character_not_primitive_stack(self):
        farmer = self.read("scripts/farmer.gd")
        # A finished authored character must be imported and instantiated.
        self.assertRegex(farmer, r'(load|preload)\s*\(\s*["\']res://[^"\']+\.(glb|gltf|tscn)["\']')
        self.assertNotRegex(farmer, r'(CapsuleMesh|SphereMesh|CylinderMesh)\.new\s*\(')

    def test_world_physical_structures(self):
        valley = self.read("scripts/valley.gd")
        self.assertIn("StaticBody3D.new()", valley)
        # A floor collider alone does not make houses or trees tangible.
        for method in ("_house", "_tree"):
            match = re.search(r'^func '+method+r'\([^\n]*\).*?(?=^func |\Z)', valley, re.M | re.S)
            self.assertIsNotNone(match)
            self.assertRegex(match.group(), r'(CollisionShape3D|create_trimesh_collision|create_convex_collision|solid_box|collision_body)', method+" lacks a physical collider")

    def test_streamed_world_not_145_unit_floor(self):
        valley = self.read("scripts/valley.gd")
        self.assertNotRegex(valley, r'Vector3\(145,\s*1,\s*145\)')
        # This is a structural signal only; actual 32x32 / 3x3 streaming
        # and boundary crossing must additionally be proven in native Godot.
        self.assertRegex(valley, r'(chunk|stream)', "No streaming integration in launch-world script")


if __name__ == "__main__":
    unittest.main()
