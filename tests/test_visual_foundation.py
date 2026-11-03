"""Contracts for the EVERBLOOM first visual quality and avatar customization pass.

This source contract is supplemental: native Godot import and scene smoke are the
authoritative runtime checks. No copyrighted third-party assets are required.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class VisualFoundationTests(unittest.TestCase):
    def read(self, name):
        return (ROOT / name).read_text(encoding="utf-8")

    def test_world_registers_new_visual_pass(self):
        self.assertIn('res://scripts/visual_environment.gd', self.read("scripts/valley.gd"))
        source = self.read("scripts/visual_environment.gd")
        for feature in ("_meadow", "_orchard", "_village_details", "_wildflower", "_pond_garden"):
            self.assertIn(feature, source)
        self.assertIn("MultiMesh", source)

    def test_player_customization_is_in_game_and_persistent(self):
        source = self.read("scripts/farmer.gd")
        for action in ("KEY_C", "KEY_TAB", "KEY_LEFT", "KEY_RIGHT", "user://everbloom_avatar.cfg", "_rebuild_avatar"):
            self.assertIn(action, source)
        self.assertIn("ConfigFile", source)

    def test_hud_does_not_occlude_the_world(self):
        source = self.read("scripts/hud.gd")
        self.assertIn("ProgressBar", source)
        self.assertIn("StyleBoxFlat", source)
        self.assertNotIn("Vector2(930,185)", source)
        self.assertIn("game.latest_message", source)


if __name__ == "__main__":
    unittest.main()
