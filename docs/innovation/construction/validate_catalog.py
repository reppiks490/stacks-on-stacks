#!/usr/bin/env python3
"""Validate the construction concept tranche. Stdlib only; no game runtime changes.

This verifies catalog completeness, not that the features are implemented or native-tested.
Run: python docs/innovation/construction/validate_catalog.py --self-test
"""
from __future__ import annotations

import argparse
import copy
import json
import re
from pathlib import Path

CATALOG = Path(__file__).with_name("phase1_ten_concepts.json")
REQUIRED = (
    "id", "title", "domain", "status", "novelty_audit", "player_scenario",
    "player_verbs", "player_loop", "simulation_rules", "state_schema",
    "command_contract", "service_contracts", "controls", "original_asset_plan",
    "performance_budget", "godot_acceptance", "adversarial_tests",
    "engine_portability", "effort_estimate", "dependencies",
    "economy_and_resource_contract",
)
FORBIDDEN_EMPTY = {"todo", "tbd", "placeholder", "n/a", "none", "later"}


def validate(data: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["catalog root must be a JSON object"]
    if data.get("schema_version") != 1:
        errors.append("catalog schema_version must equal 1")
    if data.get("phase") != "A_20_ideas":
        errors.append("catalog must be the first-20 phase")
    if data.get("target_engine") != "Godot 4.x":
        errors.append("Godot must remain the sole active engine")
    if "220" not in str(data.get("gate", "")):
        errors.append("220-feature implementation gate is missing")
    concepts = data.get("concepts")
    if not isinstance(concepts, list):
        return errors + ["concepts must be a list"]
    if len(concepts) != 10:
        errors.append(f"construction phase-A tranche must have 10 concepts, got {len(concepts)}")
    seen_ids: set[str] = set()
    seen_titles: set[str] = set()
    for index, entry in enumerate(concepts):
        label = f"concept[{index}]"
        if not isinstance(entry, dict):
            errors.append(f"{label} must be an object")
            continue
        identifier = entry.get("id")
        if not isinstance(identifier, str) or not re.fullmatch(r"EB-B-\d{3}", identifier):
            errors.append(f"{label} has invalid ID")
        elif identifier in seen_ids:
            errors.append(f"duplicate ID {identifier}")
        else:
            seen_ids.add(identifier)
        title = entry.get("title")
        if not isinstance(title, str) or len(title.strip()) < 12:
            errors.append(f"{label} has no substantive title")
        elif title.casefold() in seen_titles:
            errors.append(f"{label} repeats a title")
        else:
            seen_titles.add(title.casefold())
        for key in REQUIRED:
            value = entry.get(key)
            if value is None or value == "" or value == [] or value == {}:
                errors.append(f"{label} missing substantive {key}")
            elif isinstance(value, str) and value.strip().casefold() in FORBIDDEN_EMPTY:
                errors.append(f"{label} has placeholder {key}")
        if entry.get("status") != "specified_pending_review":
            errors.append(f"{label} must remain pending review until both tranches pass")
        controls = entry.get("controls")
        if not isinstance(controls, dict) or not all(
            isinstance(controls.get(k), str) and len(controls[k]) >= 24
            for k in ("mouse_keyboard", "gamepad", "touch")
        ):
            errors.append(f"{label} requires concrete mouse/gamepad/touch mappings")
        schema = entry.get("state_schema")
        if not isinstance(schema, dict) or schema.get("version") != 1 or not (
            isinstance(schema.get("fields"), list) and len(schema["fields"]) >= 4
        ):
            errors.append(f"{label} requires versioned state with at least four fields")
        for key, minimum in (
            ("player_verbs", 3), ("original_asset_plan", 2),
            ("godot_acceptance", 3), ("adversarial_tests", 2),
            ("dependencies", 2),
        ):
            value = entry.get(key)
            if not isinstance(value, list) or len(value) < minimum or not all(
                isinstance(x, str) and len(x.strip()) >= 3 for x in value
            ):
                errors.append(f"{label} needs at least {minimum} concrete {key}")
        budget = entry.get("performance_budget")
        if not isinstance(budget, dict) or not all(
            isinstance(budget.get(k), str) and len(budget[k]) >= 30
            for k in ("desktop", "mobile")
        ):
            errors.append(f"{label} requires desktop/mobile performance budgets")
        cost = entry.get("economy_and_resource_contract")
        if not isinstance(cost, dict) or not isinstance(cost.get("resource_inputs"), dict):
            errors.append(f"{label} requires explicit resource_inputs")
        else:
            for resource, quantity in cost["resource_inputs"].items():
                if not isinstance(resource, str) or not resource:
                    errors.append(f"{label} has invalid resource key")
                if type(quantity) is not int or quantity < 0:
                    errors.append(f"{label} has negative/noninteger resource quantity")
            if not isinstance(cost.get("refund"), str) or len(cost["refund"]) < 20:
                errors.append(f"{label} requires explicit refund policy")
    expected = {f"EB-B-{i:03d}" for i in range(1, 11)}
    if seen_ids != expected:
        errors.append("IDs must be exactly EB-B-001 through EB-B-010")
    return errors


def mutation_tests(data: dict) -> int:
    mutations = [
        ("duplicate ID", lambda x: x["concepts"][1].__setitem__("id", x["concepts"][0]["id"])),
        ("missing touch controls", lambda x: x["concepts"][0]["controls"].pop("touch")),
        ("no acceptance tests", lambda x: x["concepts"][2].__setitem__("godot_acceptance", [])),
        ("negative material count", lambda x: x["concepts"][3]["economy_and_resource_contract"]["resource_inputs"].__setitem__("wood", -1)),
        ("empty state schema", lambda x: x["concepts"][4]["state_schema"].__setitem__("fields", [])),
        ("premature implementation status", lambda x: x["concepts"][5].__setitem__("status", "implemented")),
        ("wrong engine", lambda x: x.__setitem__("target_engine", "Unreal Engine 5")),
        ("missing one concept", lambda x: x["concepts"].pop()),
    ]
    for name, mutate in mutations:
        bad = copy.deepcopy(data)
        mutate(bad)
        if not validate(bad):
            raise AssertionError(f"Mutation not detected: {name}")
    return len(mutations)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    errors = validate(data)
    if errors:
        for error in errors:
            print(f"CATALOG ERROR: {error}")
        return 1
    mutations = mutation_tests(data) if args.self_test else 0
    print(
        f"CATALOG VALIDATION: {len(data['concepts'])} complete construction "
        f"concepts, {mutations} mutation checks, 0 failures; NOT gameplay proof."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
