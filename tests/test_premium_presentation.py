"""Original authored environment, usability, and desktop profiling contracts.

Native Godot integration and actual Windows GPU measurements are separate gates.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class PremiumPresentationTests(unittest.TestCase):
    def src(self, path):
        return (ROOT / path).read_text(encoding="utf-8")

    def test_scenery_has_custom_authored_geometry_and_materials(self):
        s = self.src("scripts/premium_scenery.gd")
        for symbol in ("SurfaceTool", "ShaderMaterial", "MultiMesh", "func _make_petal_mesh(",
                       "func _plant_flowers(", "func _make_bridge(", "func dress_settlement(",
                       "func build_homestead("):
            self.assertIn(symbol, s)
        self.assertIn("season", s)

    def test_world_integrates_lod_aware_scenery(self):
        world = self.src("scripts/continental_world.gd")
        valley = self.src("scripts/valley.gd")
        self.assertIn("res://scripts/premium_scenery.gd", world)
        self.assertIn("dress_settlement(", world)
        self.assertIn("res://scripts/premium_scenery.gd", valley)
        self.assertIn("build_homestead(", valley)

    def test_f9_profiler_exposes_actual_frame_measurements(self):
        source = self.src("scripts/desktop_profiler.gd")
        for token in ("Engine.get_frames_per_second()", "Performance.get_monitor(",
                      "KEY_F9", "user://everbloom_performance_latest.json",
                      "func _write_report(", "func _sample_frame("):
            self.assertIn(token, source)
        self.assertNotIn("target_fps = 60", source)
        self.assertIn("fps_p10", source)

    def test_profiler_and_exploration_are_live_runtime_components(self):
        game = self.src("scripts/game.gd")
        world = self.src("scripts/continental_world.gd")
        self.assertIn('res://scripts/desktop_profiler.gd', game)
        self.assertIn('profiler.setup(self)', game)
        self.assertIn('res://scripts/exploration_system.gd', world)
        self.assertIn('exploration.setup(game,self)', world)
        exploration = self.src("scripts/exploration_system.gd")
        for token in ("ConfigFile", "KEY_L", "visited_hubs", "visited_biomes", "func _discover_nearby(", "func _toggle_journal("):
            self.assertIn(token, exploration)

    def test_safe_powershell_launcher_and_reset_backup(self):
        script = self.src("tools/launch_everbloom.ps1")
        self.assertIn("Get-Command", script)
        self.assertIn("Godot", script)
        self.assertIn("--path", script)
        self.assertIn("ResetSaves", script)
        self.assertIn("Copy-Item", script)
        self.assertIn("Read-Host", script)
        self.assertIn("Test-Path", script)


if __name__ == "__main__":
    unittest.main()
