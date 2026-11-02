#!/usr/bin/env python3
"""EVERBLOOM source integrity gate. This does NOT prove Godot runtime or art quality."""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
SCRIPTS = ("game", "farmer", "valley", "farm", "village", "animals", "hud")
REQUIRED_DATA = ("world", "crops", "villagers", "animals", "recipes", "quests")
EXPECTED_SEASONS = ("Spring", "Summer", "Autumn", "Winter")


def read(name: str) -> dict:
    path = DATA / (name + ".json")
    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise ValueError(f"{name}: expected JSON object")
    return document


def validate_catalogs(documents: dict[str, dict]) -> list[str]:
    failures: list[str] = []
    def require(ok: bool, why: str):
        if not ok:
            failures.append(why)

    world = documents["world"]
    crops = documents["crops"]["crops"]
    villagers = documents["villagers"]["villagers"]
    animals = documents["animals"]["animals"]
    recipes = documents["recipes"]["recipes"]
    quests = documents["quests"]["quests"]

    for name, value in documents.items():
        require(value.get("schema_version") == 1, f"{name}: schema version unsupported")
    require(world.get("seasons") == list(EXPECTED_SEASONS), "season set/order drift")
    require(world.get("days_per_season") == 14, "season day duration drift")
    require(world.get("restoration_goal") == 100, "restoration gate drift")
    require(len(world.get("regions", [])) >= 5, "world region coverage missing")
    require(len(crops) >= 8, "eight distinct original crops required")
    require(len(villagers) >= 6, "six original villagers required")
    require(len(animals) >= 3, "three livestock archetypes required")
    require(len(quests) >= 4, "restoration and onboarding quest coverage missing")

    def unique(records: list[dict], family: str) -> set[str]:
        ids = [str(row.get("id", "")) for row in records]
        require(all(ids), f"{family}: blank id")
        require(len(ids) == len(set(ids)), f"{family}: duplicate id")
        return set(ids)

    crop_ids = unique(crops, "crops")
    unique(villagers, "villagers")
    unique(animals, "animals")
    unique(quests, "quests")
    unique(world.get("regions", []), "regions")
    unique(recipes, "recipes")
    require(len({str(v.get("name", "")).casefold() for v in villagers}) == len(villagers),
            "villagers: duplicate display name")

    for crop in crops:
        cid = crop.get("id", "")
        require(isinstance(crop.get("days"), int) and crop.get("days", -1) >= 2,
                f"{cid}: invalid growth days")
        require(isinstance(crop.get("water_days"), int) and 1 <= crop["water_days"] <= crop["days"],
                f"{cid}: impossible watering cost")
        require(isinstance(crop.get("yield"), int) and 1 <= crop["yield"] <= 10,
                f"{cid}: invalid yield")
        require(isinstance(crop.get("seed_price"), int) and 0 < crop["seed_price"] < crop["sell_price"],
                f"{cid}: invalid starter economy")
        require(set(crop.get("seasons", [])).issubset(EXPECTED_SEASONS)
                and bool(crop.get("seasons")), f"{cid}: invalid season list")
        require(bool(re.fullmatch(r"#[0-9a-fA-F]{6}", str(crop.get("color", "")))),
                f"{cid}: invalid crop color")

    for animal in animals:
        aid = animal.get("id", "")
        require(animal.get("product") in {"egg", "milk", "wool"},
                f"{aid}: unknown product")
        require(isinstance(animal.get("production_days"), int)
                and 1 <= animal.get("production_days", -1) <= 14,
                f"{aid}: invalid production cycle")

    ingredient_ids = crop_ids | {"wild_herb", "wood", "stone", "fish", "milk",
                                  "egg", "wool", "flour", "shell"}
    all_outputs: set[str] = set()
    for recipe in recipes:
        rid = recipe["id"]
        require(bool(recipe.get("inputs")), f"{rid}: no ingredients")
        require(bool(recipe.get("output")), f"{rid}: no outputs")
        for ingredient, quantity in recipe.get("inputs", {}).items():
            require(ingredient in ingredient_ids, f"{rid}: unknown ingredient {ingredient}")
            require(isinstance(quantity, int) and quantity > 0, f"{rid}: invalid ingredient quantity")
        for output, quantity in recipe.get("output", {}).items():
            all_outputs.add(output)
            require(isinstance(quantity, int) and quantity > 0, f"{rid}: invalid output quantity")

    for person in villagers:
        rid = person["id"]
        require(len(person.get("dialogue", [])) >= 2, f"{rid}: not enough original lines")
        require(len(person.get("home", [])) == 3, f"{rid}: invalid home coordinate")
        require(bool(person.get("preferences")), f"{rid}: missing preferred gifts")
        for gift in person.get("preferences", []):
            require(gift in ingredient_ids | all_outputs,
                    f"{rid}: unknown preferred gift {gift}")

    for quest in quests:
        require(isinstance(quest.get("target"), int) and quest["target"] > 0,
                f"{quest['id']}: invalid quest target")
    return failures


def validate_tree() -> list[str]:
    errors: list[str] = []
    for stem in SCRIPTS:
        source_path = ROOT / "scripts" / (stem + ".gd")
        if not source_path.is_file():
            errors.append(f"missing Godot script: {stem}")
        elif "extends " not in source_path.read_text(encoding="utf-8"):
            errors.append(f"invalid Godot script header: {stem}")
    if not (ROOT / "project.godot").is_file():
        errors.append("missing project.godot")
    if not (ROOT / "scenes/main.tscn").is_file():
        errors.append("missing main scene")
    if "res://scripts/game.gd" not in (ROOT / "scenes/main.tscn").read_text(encoding="utf-8"):
        errors.append("main scene must start original gameplay manager")

    sources = "\n".join(p.read_text(encoding="utf-8") for p in (ROOT / "scripts").glob("*.gd"))
    if "res://scripts/farm.gd" not in sources or "res://scripts/village.gd" not in sources:
        errors.append("main game must integrate farming and villagers")
    if "save_game" not in sources or "load_game" not in sources:
        errors.append("save or restore entrypoint missing")

    provenance_path = ROOT / "assets/provenance.json"
    if not provenance_path.is_file():
        errors.append("asset provenance is absent")
    else:
        document = json.loads(provenance_path.read_text(encoding="utf-8"))
        recorded = {r["path"] for r in document.get("assets", [])}
        for asset in (ROOT / "assets").rglob("*"):
            if asset.is_file() and asset.name != "provenance.json":
                relative = asset.relative_to(ROOT).as_posix()
                if relative not in recorded:
                    errors.append(f"unrecorded asset: {relative}")
    workflow = ROOT / ".github/workflows/everbloom-native-validation.yml"
    if not workflow.is_file():
        errors.append("missing native Godot source CI")
    else:
        content = workflow.read_text(encoding="utf-8")
        if "Godot_v4.7.2-stable_linux.x86_64" not in content:
            errors.append("CI lacks pinned Godot runtime")
        if re.search(r"(?:^\s*(?:uses|run):[^\n]*codex)", content, re.I | re.M):
            errors.append("forbidden Codex invocation")
    return errors


def check() -> list[str]:
    try:
        documents = {name: read(name) for name in REQUIRED_DATA}
    except (OSError, ValueError, TypeError) as exc:
        return [str(exc)]
    return validate_catalogs(documents) + validate_tree()


def main() -> int:
    issues = check()
    for issue in issues:
        print("ERROR:", issue)
    if issues:
        return 1
    print("PASS: EVERBLOOM original content schema and source tree; native Godot evidence separate.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
