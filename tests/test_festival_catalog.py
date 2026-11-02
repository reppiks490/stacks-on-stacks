"""Fail-closed original festival catalog/implementation invariants.

This is a source contract, not evidence of gameplay animation or shipped art.
"""
from __future__ import annotations

import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "data/festivals.json"
SEASONS = {"Spring", "Summer", "Autumn", "Winter"}
LEGAL_ITEMS = {
    "turnip_seed", "turnip", "bluebell", "fish", "strawberry",
    "wild_herb", "carrot", "pumpkin", "wool", "milk", "wood", "egg"
}


def read():
    return json.loads(PATH.read_text(encoding="utf-8"))


def validate(doc):
    issues = []
    if doc.get("schema_version") != 1:
        issues.append("unrecognized festival schema")
    venue = doc.get("venue", {})
    if venue.get("region_id") != "larkspur_village":
        issues.append("festival must use original canonical village")
    if venue.get("square") != [30, 0, 0]:
        issues.append("festival stage location mismatch")
    if venue.get("radius") != 8:
        issues.append("festival interaction must be spatially bounded")
    if venue.get("open_hour") != 8 or venue.get("close_hour") != 20:
        issues.append("unsafe activity window")
    entries = doc.get("festivals", [])
    if len(entries) != 12:
        issues.append("expected twelve authored seasonal festivals")
    seen_ids = set()
    seen_slots = set()
    for entry in entries:
        event_id = entry.get("id", "")
        season = entry.get("season")
        day = entry.get("day")
        if event_id in seen_ids or not event_id:
            issues.append("duplicate/blank festival id")
        seen_ids.add(event_id)
        if (season, day) in seen_slots:
            issues.append("two festivals collide on one village calendar day")
        seen_slots.add((season, day))
        if season not in SEASONS or type(day) is not int or not 1 <= day <= 14:
            issues.append("invalid season/day")
        if len(entry.get("title", "")) < 5 or len(entry.get("description", "")) < 18:
            issues.append("festival needs an original title and descriptive content")
        if entry.get("activity") not in {"seedling", "gathering", "water", "lanterns"}:
            issues.append("unexpected event mechanic")
        if not entry.get("weather_fallback"):
            issues.append("rain-unsafe celebration")
        donation = entry.get("donation", {})
        reward = entry.get("reward", {})
        if donation.get("item") not in LEGAL_ITEMS:
            issues.append("unavailable donation item")
        if type(donation.get("quantity")) is not int or not 1 <= donation.get("quantity", 0) <= 4:
            issues.append("invalid donation quantity")
        if type(reward.get("petals")) is not int or not 1 <= reward.get("petals", 0) <= 120:
            issues.append("reward out of bounded economy")
        if type(reward.get("restoration")) is not int or not 1 <= reward.get("restoration", 0) <= 8:
            issues.append("restoration award out of bounds")
        if reward.get("ribbons") != 1:
            issues.append("one canonical original ribbon award required")
        color = entry.get("color", "")
        if not (isinstance(color, str) and len(color) == 7 and color[0] == "#"):
            issues.append("festival primary color missing")
    for season in SEASONS:
        if sum(1 for entry in entries if entry.get("season") == season) != 3:
            issues.append("missing full seasonal festival coverage")
    return issues


class FestivalCatalogTests(unittest.TestCase):
    def setUp(self):
        self.data = read()

    def test_authored_catalog(self):
        self.assertEqual(validate(self.data), [])

    def test_no_duplicate_ids(self):
        doc = json.loads(json.dumps(self.data))
        doc["festivals"][1]["id"] = doc["festivals"][0]["id"]
        self.assertTrue(validate(doc))

    def test_no_same_day_clashes(self):
        doc = json.loads(json.dumps(self.data))
        doc["festivals"][1]["day"] = doc["festivals"][0]["day"]
        self.assertTrue(validate(doc))

    def test_no_unbounded_gold_rewards(self):
        doc = json.loads(json.dumps(self.data))
        doc["festivals"][0]["reward"]["petals"] = 10_000_000
        self.assertTrue(validate(doc))

    def test_no_unavailable_offerings(self):
        doc = json.loads(json.dumps(self.data))
        doc["festivals"][0]["donation"]["item"] = "unknown_rare_asset"
        self.assertTrue(validate(doc))

    def test_no_duplicate_ribbons(self):
        doc = json.loads(json.dumps(self.data))
        doc["festivals"][0]["reward"]["ribbons"] = 500
        self.assertTrue(validate(doc))

    def test_year_bound_native_ledger_source(self):
        source = (ROOT / "scripts/festivals.gd").read_text(encoding="utf-8")
        for symbol in (
            "func today()", "func act(", "func save_state()", "func load_state(",
            "awarded.has(key)", "game.consume_item(item, required)",
            "game.spend_energy(ENERGY_COST)", "game.day_epoch()", "game.year"
        ):
            self.assertIn(symbol, source)

    def test_main_scene_has_real_gameplay_hook(self):
        source = (ROOT / "scripts/game.gd").read_text(encoding="utf-8")
        for symbol in (
            'res://scripts/festivals.gd',
            'event.is_action_pressed("festival")',
            '"festivals":festivals.save_state()',
            'festivals.load_state(content.get("festivals", {}))',
        ):
            self.assertIn(symbol, source)


if __name__ == "__main__":
    unittest.main()
