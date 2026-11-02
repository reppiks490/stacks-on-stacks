#!/usr/bin/env python3
"""Offline EVERBLOOM content/provenance validator. Standard library only.

This is a source/data gate, NOT a substitute for native Godot import/runtime.
"""
from __future__ import annotations
import json
import re
from pathlib import Path
from xml.etree import ElementTree

ROOT = Path(__file__).resolve().parents[1]
SEASONS = {"Spring", "Summer", "Autumn", "Winter"}
REQUIRED = [
    "project.godot", "scenes/main.tscn", "scripts/game.gd",
    "scripts/farm.gd", "scripts/village.gd", "scripts/animals.gd",
    "scripts/valley.gd", "scripts/farmer.gd", "scripts/hud.gd",
    "data/crops.json", "data/villagers.json", "data/animals.json",
    "data/recipes.json", "data/quests.json", "data/world.json",
    "assets/provenance.json", "assets/vector/everbloom_emblem.svg",
    ".github/workflows/everbloom-native-validation.yml",
]

def require(condition: bool, description: str) -> None:
    if not condition:
        raise ValueError(description)

def read_json(path: str) -> dict:
    obj = json.loads((ROOT / path).read_text(encoding="utf-8"))
    require(isinstance(obj, dict), f"{path}: expected object")
    require(obj.get("schema_version") == 1, f"{path}: schema_version must equal 1")
    return obj

def records(payload: dict, key: str, path: str) -> list:
    values = payload.get(key)
    require(isinstance(values, list) and bool(values), f"{path}: nonempty {key} required")
    require(all(isinstance(v, dict) for v in values), f"{path}: {key} entries must be objects")
    ids = [v.get("id") for v in values]
    require(all(isinstance(v, str) and re.fullmatch(r"[a-z][a-z0-9_]*", v) for v in ids),
            f"{path}: IDs must be stable lowercase identifiers")
    require(len(ids) == len(set(ids)), f"{path}: duplicate IDs")
    return values

def validate() -> dict:
    for path in REQUIRED:
        require((ROOT / path).is_file(), f"missing {path}")
    scene = (ROOT / "scenes/main.tscn").read_text(encoding="utf-8")
    require("res://scripts/game.gd" in scene, "main scene must reference game.gd")
    for gd_path in (ROOT / "scripts").glob("*.gd"):
        text = gd_path.read_text(encoding="utf-8")
        for ref in re.findall(r"res://([A-Za-z0-9_./-]+\.gd)", text):
            require((ROOT / ref).is_file(), f"{gd_path.name}: missing script {ref}")

    crop_rows = records(read_json("data/crops.json"), "crops", "data/crops.json")
    crop_ids = {row["id"] for row in crop_rows}
    for row in crop_rows:
        require(isinstance(row.get("seasons"), list) and bool(row["seasons"])
                and set(row["seasons"]).issubset(SEASONS), f"crop {row['id']}: invalid seasons")
        for field in ("days", "water_days", "seed_price", "sell_price", "yield"):
            require(type(row.get(field)) is int and row[field] > 0, f"crop {row['id']}: {field}")
        require(row["water_days"] <= row["days"], f"crop {row['id']}: impossible water_days")
        require(isinstance(row.get("color"), str) and re.fullmatch(r"#[0-9a-fA-F]{6}", row["color"]),
                f"crop {row['id']}: invalid color")

    villagers = records(read_json("data/villagers.json"), "villagers", "data/villagers.json")
    for row in villagers:
        require(isinstance(row.get("name"), str) and row["name"].strip(), f"villager {row['id']}: name")
        require(isinstance(row.get("home"), list) and len(row["home"]) == 3
                and all(type(x) in (int, float) for x in row["home"]), f"villager {row['id']}: home")
        require(isinstance(row.get("dialogue"), list) and all(isinstance(x, str) and x.strip()
                for x in row["dialogue"]) and len(row["dialogue"]) > 0,
                f"villager {row['id']}: dialogue")
        require(isinstance(row.get("preferences"), list), f"villager {row['id']}: preferences")

    animals = records(read_json("data/animals.json"), "animals", "data/animals.json")
    for row in animals:
        for field in ("production_days", "care_reward"):
            require(type(row.get(field)) is int and row[field] > 0, f"animal {row['id']}: {field}")
        require(isinstance(row.get("product"), str) and row["product"], f"animal {row['id']}: product")

    recipes = records(read_json("data/recipes.json"), "recipes", "data/recipes.json")
    for row in recipes:
        for field in ("inputs", "output"):
            value = row.get(field)
            require(isinstance(value, dict) and bool(value) and all(
                isinstance(k, str) and k and type(n) is int and n > 0 for k, n in value.items()),
                f"recipe {row['id']}: invalid {field}")

    quests = records(read_json("data/quests.json"), "quests", "data/quests.json")
    for row in quests:
        require(type(row.get("target")) is int and row["target"] > 0, f"quest {row['id']}: target")

    world = read_json("data/world.json")
    regions = records(world, "regions", "data/world.json")
    require(world.get("seasons") == ["Spring", "Summer", "Autumn", "Winter"],
            "world: season order must match game")
    require(world.get("days_per_season") == 14, "world: days_per_season drift")
    for row in regions:
        require(isinstance(row.get("center"), list) and len(row["center"]) == 3,
                f"region {row['id']}: center")

    provenance = read_json("assets/provenance.json")
    asset_rows = provenance.get("assets", [])
    require(isinstance(asset_rows, list), "provenance: assets must be list")
    for row in asset_rows:
        require(isinstance(row, dict), "provenance: asset entry must be object")
        path = row.get("path", "")
        require(isinstance(path, str) and path.startswith("assets/")
                and ".." not in Path(path).parts and (ROOT / path).is_file(),
                f"provenance: invalid or missing asset {path}")
        require(row.get("license") and row.get("creator"), f"provenance: missing rights for {path}")
    ElementTree.parse(ROOT / "assets/vector/everbloom_emblem.svg")
    workflows = (ROOT / ".github/workflows/everbloom-native-validation.yml").read_text(encoding="utf-8")
    require(not re.search(r"(?i)(codex|openai/codex|chatgpt[-_ ]agent)", workflows),
            "workflow must not invoke Codex")
    require("contents: read" in workflows, "workflow permissions must be read-only")
    return {
        "crops": len(crop_rows), "villagers": len(villagers), "animals": len(animals),
        "recipes": len(recipes), "quests": len(quests), "regions": len(regions),
        "registered_assets": len(asset_rows), "script_files": len(list((ROOT / "scripts").glob("*.gd"))),
    }

if __name__ == "__main__":
    print("EVERBLOOM offline source/data validation:", json.dumps(validate(), sort_keys=True))
