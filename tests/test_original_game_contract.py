"""Independent original life-sim source regressions; NOT Godot engine tests."""
from __future__ import annotations

import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("everbloom_validation", ROOT / "tools/validate_project.py")
assert SPEC and SPEC.loader
validator = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validator)


class OriginalGameContractTests(unittest.TestCase):
    def setUp(self) -> None:
        self.data = {name: validator.read(name) for name in validator.REQUIRED_DATA}

    def check(self, payload=None):
        return validator.validate_catalogs(self.data if payload is None else payload)

    def mutate(self, name: str, fn):
        documents = copy.deepcopy(self.data)
        fn(documents[name])
        self.assertTrue(self.check(documents))

    def test_all_source_contracts(self):
        self.assertEqual(validator.check(), [])

    def test_all_catalogs_unique(self):
        self.assertEqual(self.check(), [])

    def test_missing_season_rejected(self):
        self.mutate("world", lambda d: d["seasons"].remove("Winter"))

    def test_missing_region_rejected(self):
        self.mutate("world", lambda d: d["regions"].pop())

    def test_missing_crop_rejected(self):
        self.mutate("crops", lambda d: d["crops"].pop())

    def test_duplicate_crop_id_rejected(self):
        self.mutate("crops", lambda d: d["crops"].append(dict(d["crops"][0])))

    def test_invalid_water_days_rejected(self):
        self.mutate("crops", lambda d: d["crops"][0].update(water_days=999))

    def test_unsupported_crop_season_rejected(self):
        self.mutate("crops", lambda d: d["crops"][0].update(seasons=["Monsoon"]))

    def test_negative_economy_rejected(self):
        self.mutate("crops", lambda d: d["crops"][0].update(seed_price=-5))

    def test_invalid_crop_color_rejected(self):
        self.mutate("crops", lambda d: d["crops"][0].update(color="#bad"))

    def test_duplicate_villager_rejected(self):
        self.mutate("villagers", lambda d: d["villagers"].append(dict(d["villagers"][0])))

    def test_missing_personality_dialogue_rejected(self):
        self.mutate("villagers", lambda d: d["villagers"][0].update(dialogue=[]))

    def test_unknown_gift_item_rejected(self):
        self.mutate("villagers", lambda d: d["villagers"][0].update(preferences=["secret_cheat_item"]))

    def test_bad_livestock_product_rejected(self):
        self.mutate("animals", lambda d: d["animals"][0].update(product="gold_bars"))

    def test_zero_livestock_production_rejected(self):
        self.mutate("animals", lambda d: d["animals"][0].update(production_days=0))

    def test_recipe_unknown_ingredient_rejected(self):
        self.mutate("recipes", lambda d: d["recipes"][0].update(inputs={"unowned_property":1}))

    def test_recipe_zero_output_rejected(self):
        self.mutate("recipes", lambda d: d["recipes"][0].update(output={"tea":0}))

    def test_quest_without_target_rejected(self):
        self.mutate("quests", lambda d: d["quests"][0].update(target=0))

    def test_restoration_gate_rejected(self):
        self.mutate("world", lambda d: d.update(restoration_goal=0))

    def test_farm_seed_and_day_integration_exist(self):
        code = (ROOT / "scripts/farm.gd").read_text()
        for required in ("func act(", "func next_day(", "func save_state(", "func load_state("):
            self.assertIn(required, code)

    def test_saved_state_includes_villagers_and_animals(self):
        code = (ROOT / "scripts/game.gd").read_text()
        for required in ('"farm":farm.save_state()', '"village":village.save_state()',
                         '"animals":animals.save_state()'):
            self.assertIn(required, code)

    def test_no_former_game_assets_left_in_current_tree(self):
        self.assertFalse((ROOT / "assets/models/sableblade.obj").exists())
        self.assertFalse((ROOT / "scripts/combat_rules.gd").exists())


if __name__ == "__main__":
    unittest.main()
