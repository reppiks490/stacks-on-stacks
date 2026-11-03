"""EVERBLOOM continental systems acceptance contracts.

This intentionally checks the source-level API and coverage. Native Godot import,
120-frame smoke, and real gameplay/device screenshots remain independent gates.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


def source(name):
    return (ROOT / name).read_text(encoding="utf-8")


class ContinentalExpansionContracts(unittest.TestCase):
    def test_world_surface_is_one_hundred_times_original(self):
        s = source("scripts/continental_world.gd")
        self.assertIn("const CONTINENT_SIDE: float = 1450.0", s)
        self.assertIn("const CHUNK_SIDE: float = 145.0", s)
        self.assertIn("const GRID_WIDTH: int = 10", s)
        self.assertIn("func _stream_neighborhood", s)
        self.assertIn("func _unload_chunk", s)
        self.assertIn("MultiMesh", s)
        self.assertIn("func _make_chunk", s)

    def test_world_visual_lanes_and_points_of_interest(self):
        s = source("scripts/continental_world.gd")
        for value in ("Frostpetal", "Sunspire", "Moonharbor", "Briarford", "Fernwater", "Hearthmere"):
            self.assertIn(value, s)
        self.assertIn("func _make_settlement", s)
        self.assertIn("func _make_panorama", s)
        self.assertIn("func _create_atlas", s)

    def test_live_npcs_and_market(self):
        s = source("scripts/frontier_society.gd")
        for value in ("func setup(", "func spawn_for_chunk(", "func _interact(", "func _trade(", "func _quest(", "func _make_resident("):
            self.assertIn(value, s)
        self.assertIn("ConfigFile", s)
        self.assertIn("flea", s.lower())

    def test_companions_can_be_tamed_and_ridden(self):
        s = source("scripts/wild_companions.gd")
        for value in ("func setup(", "func _tame(", "func _mount(", "func _pet(", "func _save(", "ConfigFile"):
            self.assertIn(value, s)
        self.assertIn("KEY_N", s)
        self.assertIn("KEY_B", s)
        self.assertIn("walking_speed", s)

    def test_existing_valley_and_character_compatibility(self):
        valley = source("scripts/valley.gd")
        self.assertIn('res://scripts/continental_world.gd', valley)
        farmer = source("scripts/farmer.gd")
        self.assertIn("var ride_offset:", farmer)
        self.assertIn("ride_offset", farmer)

if __name__ == "__main__":
    unittest.main()
