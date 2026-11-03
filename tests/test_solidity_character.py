"""First-class contracts for solid-world and non-primitive avatar rebuild.

Source contracts run before native Godot acceptance. Real physics rays and
movement are validated separately by tests/native_solidity_acceptance.gd.
"""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

def source(path):
    return (ROOT/path).read_text(encoding="utf-8")

class SolidWorldCharacterContracts(unittest.TestCase):
    def test_reusable_physical_collision_layer(self):
        s=source("scripts/world_collision.gd")
        for token in ["static func solid_box(", "StaticBody3D.new()", "CollisionShape3D.new()", "BoxShape3D.new()", "collision_layer", "static func perimeter_barrier("]:
            self.assertIn(token,s)

    def test_homestead_buildings_are_physical(self):
        s=source("scripts/valley.gd")
        self.assertIn('res://scripts/world_collision.gd',s)
        self.assertIn("WorldCollision.solid_box(",s)
        self.assertIn("func _house(",s)

    def test_all_continental_buildings_are_physical(self):
        s=source("scripts/continental_world.gd")
        self.assertIn('res://scripts/world_collision.gd',s)
        self.assertIn("WorldCollision.solid_box(",s)
        self.assertIn("func _perimeter_chunk(",s)
        self.assertIn("func _recover_fall(",s)
        self.assertIn("last_safe_position",s)

    def test_authored_sculpted_avatar_is_not_shape_stack(self):
        s=source("scripts/sculpted_humanoid.gd")
        self.assertIn("SurfaceTool.new()",s)
        self.assertIn("func configure(",s)
        self.assertIn("func _ring_mesh(",s)
        self.assertIn("func _face(",s)
        self.assertIn("func _hair(",s)
        self.assertNotIn("SphereMesh.new()",s)
        self.assertNotIn("CapsuleMesh.new()",s)
        self.assertNotIn("BoxMesh.new()",s)
        f=source("scripts/farmer.gd")
        n=source("scripts/frontier_society.gd")
        self.assertIn("res://scripts/sculpted_humanoid.gd",f)
        self.assertIn("res://scripts/sculpted_humanoid.gd",n)
        village=source("scripts/village.gd")
        self.assertIn("res://scripts/sculpted_humanoid.gd",village)
        self.assertNotIn("CapsuleMesh.new()",village)

    def test_avatar_more_control_and_legacy_save_compatibility(self):
        s=source("scripts/farmer.gd")
        for key in ['"jaw"','"brow"','"nose"','"mouth"','"height"','"footwear"','"hair_length"','"eye_size"']:
            self.assertIn(key,s)
        self.assertIn("user://everbloom_avatar.cfg",s)
        self.assertIn("ConfigFile",s)
        self.assertIn("KEY_C",s)

    def test_modular_architecture_replaces_box_house_shells(self):
        architecture=source("scripts/sculpted_architecture.gd")
        for token in ("SurfaceTool.new()", "ShaderMaterial.new()", "func build_house(", "func _wall_shell(", "func _roof_mesh(", "func _facade_details(", "WorldCollision.solid_box("):
            self.assertIn(token,architecture)
        self.assertNotIn("BoxMesh.new()",architecture)
        self.assertIn("res://scripts/sculpted_architecture.gd",source("scripts/valley.gd"))
        self.assertIn("res://scripts/sculpted_architecture.gd",source("scripts/continental_world.gd"))

    def test_original_sculpted_foliage_replaces_spheres(self):
        foliage=source("scripts/sculpted_foliage.gd")
        for feature in ("SurfaceTool.new()","static func make_canopy_mesh(", "static func make_trunk_mesh(", "static func make_rock_mesh("):
            self.assertIn(feature,foliage)
        for path in ("scripts/valley.gd","scripts/visual_environment.gd","scripts/continental_world.gd"):
            self.assertIn("res://scripts/sculpted_foliage.gd",source(path))
        valley=source("scripts/valley.gd")
        a=valley.index("func _hills(")
        b=valley.index("func _wayfinding(",a)
        self.assertNotIn("sphere(",valley[a:b])

    def test_native_acceptance_is_routed_in_non_codex_workflow(self):
        s=source(".github/workflows/everbloom-solid-world-acceptance.yml")
        self.assertIn("native_solidity_acceptance.gd",s)
        self.assertIn("native_avatar_acceptance.gd",s)
        self.assertNotIn("codex",s.lower())

if __name__=="__main__":
    unittest.main()
