#!/usr/bin/env python3
"""Strict phase-A Emergence concept validation (NOT gameplay proof).

Usage:
  python3 docs/innovation/emergence/validate_catalog.py --self-test
  python3 docs/innovation/emergence/validate_catalog.py --builder-file docs/innovation/construction/phase1_ten_concepts.json --self-test

The optional cross-loop check requires Builder's catalog to be present in the SAME
checkout. The isolated Emergence branch does not falsely claim a merged 20-feature
gate or the later 220-feature implementation gate.
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
    "economy_and_resource_contract", "cross_loop_boundary", "implementation_phases",
)
PLACEHOLDERS = {"todo", "tbd", "placeholder", "n/a", "none", "later", "fixme"}


def substantive(value: object) -> bool:
    if value is None or value == "" or value == [] or value == {}:
        return False
    if isinstance(value, str):
        return value.strip().casefold() not in PLACEHOLDERS and len(value.strip()) >= 3
    return True


def validate(data: object) -> list[str]:
    errors: list[str] = []
    if not isinstance(data, dict):
        return ["catalog root must be object"]
    if data.get("schema_version") != 1 or data.get("phase") != "A_20_ideas":
        errors.append("phase-A schema must be version 1")
    if data.get("target_engine") != "Godot 4.x":
        errors.append("Godot 4.x is the sole implementation engine")
    if "220" not in str(data.get("gate", "")):
        errors.append("explicit 220-feature implementation gate required")
    concepts = data.get("concepts")
    if not isinstance(concepts, list):
        return errors + ["concepts must be a list"]
    if len(concepts) != 10:
        errors.append(f"Emergence must specify exactly ten phase-A concepts, found {len(concepts)}")
    ids: set[str] = set()
    titles: set[str] = set()
    domains: set[str] = set()
    for i, c in enumerate(concepts):
        label = f"concept[{i}]"
        if not isinstance(c, dict):
            errors.append(f"{label}: must be object")
            continue
        for key in REQUIRED:
            if not substantive(c.get(key)):
                errors.append(f"{label}: missing/placeholder {key}")
        identifier = c.get("id")
        if not isinstance(identifier, str) or not re.fullmatch(r"EB-E-\\d{3}", identifier):
            errors.append(f"{label}: invalid ID")
        elif identifier in ids:
            errors.append(f"{label}: duplicate ID")
        else:
            ids.add(identifier)
        title = c.get("title")
        if not isinstance(title, str) or len(title) < 16 or title.casefold() in titles:
            errors.append(f"{label}: invalid or repeated title")
        else:
            titles.add(title.casefold())
        domain = c.get("domain")
        if not isinstance(domain, str) or domain in domains:
            errors.append(f"{label}: invalid or repeated domain")
        else:
            domains.add(domain)
        if c.get("status") != "specified_pending_review":
            errors.append(f"{label}: must remain pending cross-loop review")
        if not isinstance(c.get("novelty_audit"), str) or len(c["novelty_audit"]) < 90:
            errors.append(f"{label}: novelty audit lacks comparison")
        if not isinstance(c.get("cross_loop_boundary"), str) or "B-" not in c["cross_loop_boundary"]:
            errors.append(f"{label}: missing explicit Builder ownership boundary")
        for key, minimum in (
            ("player_verbs", 4), ("player_loop", 1), ("simulation_rules", 3),
            ("command_contract", 3), ("service_contracts", 2),
            ("original_asset_plan", 2), ("godot_acceptance", 3),
            ("adversarial_tests", 2), ("dependencies", 2),
            ("implementation_phases", 3),
        ):
            values = c.get(key)
            if not isinstance(values, list) or len(values) < minimum or not all(
                isinstance(x, str) and len(x.strip()) >= 12 for x in values
            ):
                errors.append(f"{label}: insufficient substantive {key}")
        schema = c.get("state_schema")
        if not isinstance(schema, dict) or schema.get("version") != 1 or not isinstance(schema.get("fields"), list) or len(schema["fields"]) < 4:
            errors.append(f"{label}: invalid versioned state schema")
        controls = c.get("controls")
        if not isinstance(controls, dict) or not all(
            isinstance(controls.get(k), str) and len(controls[k]) >= 30
            for k in ("mouse_keyboard", "gamepad", "touch")
        ):
            errors.append(f"{label}: missing device controls")
        budgets = c.get("performance_budget")
        if not isinstance(budgets, dict) or not all(
            isinstance(budgets.get(k), str) and len(budgets[k]) >= 45
            for k in ("desktop", "mobile")
        ):
            errors.append(f"{label}: missing desktop/mobile budgets")
        effort = c.get("effort_estimate")
        if not isinstance(effort, dict) or effort.get("size") not in ("S", "M", "L", "XL") or not (
            isinstance(effort.get("risks"), list) and len(effort["risks"]) >= 2
        ) or not re.fullmatch(r"\\d+-\\d+", str(effort.get("estimated_engineering_days", ""))):
            errors.append(f"{label}: invalid effort/risk estimate")
        economy = c.get("economy_and_resource_contract")
        if not isinstance(economy, dict) or not isinstance(economy.get("resource_inputs"), dict) or not (
            isinstance(economy.get("refund"), str) and len(economy["refund"]) >= 35
        ):
            errors.append(f"{label}: invalid economy/refund contract")
        else:
            for key, qty in economy["resource_inputs"].items():
                if not isinstance(key, str) or not key or type(qty) is not int or qty < 0:
                    errors.append(f"{label}: invalid resource debit")
    if ids != {f"EB-E-{i:03d}" for i in range(1, 11)}:
        errors.append("IDs must be exactly EB-E-001..EB-E-010")
    return errors


def validate_combined(emergence: dict, builder: dict) -> list[str]:
    errors: list[str] = []
    bs = builder.get("concepts")
    es = emergence.get("concepts")
    if not isinstance(bs, list) or len(bs) != 10 or not isinstance(es, list) or len(es) != 10:
        return ["both ten-record tranches are required for cross-loop audit"]
    b_ids = [x.get("id") for x in bs if isinstance(x, dict)]
    if set(b_ids) != {f"EB-B-{i:03d}" for i in range(1, 11)} or len(b_ids) != 10:
        errors.append("Builder IDs must be EB-B-001..EB-B-010")
    all_entries = bs + es
    for key in ("id", "title", "domain"):
        values = [str(x.get(key, "")).strip().casefold() for x in all_entries]
        if len(values) != len(set(values)):
            errors.append(f"cross-loop duplicate {key}")
    if builder.get("target_engine") != "Godot 4.x":
        errors.append("Builder must also remain Godot-first")
    # This is a mechanical collision check only. A Principal/owner novelty review
    # must still accept gameplay boundaries before phase-B expansion.
    return errors


def mutation_tests(data: dict) -> int:
    mutations = [
        ("duplicate ID", lambda x: x["concepts"][1].__setitem__("id", x["concepts"][0]["id"])),
        ("missing touch", lambda x: x["concepts"][0]["controls"].pop("touch")),
        ("missing native acceptance", lambda x: x["concepts"][2].__setitem__("godot_acceptance", [])),
        ("negative resource", lambda x: x["concepts"][1]["economy_and_resource_contract"]["resource_inputs"].__setitem__("reed_seed", -2)),
        ("no state fields", lambda x: x["concepts"][3]["state_schema"].__setitem__("fields", [])),
        ("premature implementation", lambda x: x["concepts"][4].__setitem__("status", "implemented")),
        ("wrong engine", lambda x: x.__setitem__("target_engine", "Unreal Engine 5")),
        ("missing concept", lambda x: x["concepts"].pop()),
        ("duplicate domain", lambda x: x["concepts"][1].__setitem__("domain", x["concepts"][0]["domain"])),
        ("missing builder boundary", lambda x: x["concepts"][6].__setitem__("cross_loop_boundary", "unknown")),
        ("missing implementation phases", lambda x: x["concepts"][7].__setitem__("implementation_phases", [])),
        ("empty economic refund", lambda x: x["concepts"][8]["economy_and_resource_contract"].__setitem__("refund", "")),
    ]
    for name, mutate in mutations:
        bad = copy.deepcopy(data)
        mutate(bad)
        if not validate(bad):
            raise AssertionError(f"Undetected invalid catalog mutation: {name}")
    return len(mutations)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--builder-file", type=Path)
    args = parser.parse_args()
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    errors = validate(data)
    if args.builder_file:
        builder = json.loads(args.builder_file.read_text(encoding="utf-8"))
        errors += validate_combined(data, builder)
    if errors:
        for err in errors:
            print("EMERGENCE CATALOG ERROR:", err)
        return 1
    mutations = mutation_tests(data) if args.self_test else 0
    print(f"EMERGENCE CATALOG VALIDATION: 10 specified concepts, {mutations} negative mutation checks, 0 failures.")
    if args.builder_file:
        print("CROSS-LOOP MECHANICAL CHECK: 20 distinct IDs/titles/domains; substantive novelty approval still pending.")
    else:
        print("CROSS-LOOP GATE: Builder catalog absent from this checkout; 20-idea phase NOT yet accepted.")
    print("NOT gameplay implementation or native Godot feature acceptance.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
