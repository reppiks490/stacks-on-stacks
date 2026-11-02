"""Offline contract checks. Native Godot verification is a separate CI gate."""
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from validate_project import validate, read_json  # noqa: E402


class TestEverbloomContracts(unittest.TestCase):
    def test_full_source_and_content_contract(self):
        summary = validate()
        self.assertGreaterEqual(summary["script_files"], 7)
        self.assertGreaterEqual(summary["registered_assets"], 1)

    def test_seasonal_crop_coverage(self):
        crops = read_json("data/crops.json")["crops"]
        covered = {season for crop in crops for season in crop["seasons"]}
        self.assertEqual(covered, {"Spring", "Summer", "Autumn", "Winter"})

    def test_unique_npc_and_animal_identifiers(self):
        for file, key in [("data/villagers.json", "villagers"),
                          ("data/animals.json", "animals")]:
            rows = read_json(file)[key]
            self.assertEqual(len(rows), len({x["id"] for x in rows}))

    def test_restoration_quest_exists(self):
        quests = read_json("data/quests.json")["quests"]
        self.assertTrue(any(q["kind"] == "restoration" for q in quests))

    def test_main_scene_references_real_orchestrator(self):
        scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
        self.assertIn("res://scripts/game.gd", scene)
        self.assertTrue((ROOT / "scripts/game.gd").exists())

    def test_original_assets_are_provenanced(self):
        entries = read_json("assets/provenance.json")["assets"]
        for row in entries:
            self.assertTrue((ROOT / row["path"]).exists())
            self.assertNotIn("harvest_moon", row["path"].lower())


if __name__ == "__main__":
    unittest.main()
