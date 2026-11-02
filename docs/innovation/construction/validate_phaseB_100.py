#!/usr/bin/env python3
"""Offline design-only validation for EVERBLOOM Construction Phase B.

This is NOT native Godot gameplay validation. No external dependencies/network.
"""
import argparse
import copy
import json
import re
from pathlib import Path

PATH = Path(__file__).with_name("phaseB_100_concepts.json")
DOMAINS = {
    "structural_design", "interior_living", "civic_construction",
    "ecological_landscape", "material_crafting", "site_logistics",
    "household_function", "community_events", "engineering_tooling",
    "architectural_art",
}
REQUIRED = {
    "id", "title", "domain", "status", "novelty_audit", "player_scenario",
    "player_verbs", "simulation_rules", "state_schema", "command_contract",
    "service_contracts", "controls", "original_asset_plan", "performance_budget",
    "godot_acceptance", "adversarial_tests", "engine_portability",
    "effort_estimate", "dependencies", "economy_and_resource_contract", "phaseC_gate",
}
# Frozen first-tranche titles; the Emergence catalog is separately owned and
# must be jointly deduplicated by Principal before opening Phase C.
PHASE_A_BUILDER = {
    "joinery loom", "groundweave", "framewright", "rainroof atelier",
    "roomheart", "hearth threads", "memory blueprints",
    "village build commons", "salvage ledger", "seasonwright homes",
}

def check(doc):
    problems = []
    if doc.get("schema_version") != 1 or doc.get("phase") != "B_additional_200":
        problems.append("incorrect phase/schema")
    if doc.get("engine") != "Godot 4.x":
        problems.append("engine migration is not authorized")
    if "CLOSED" not in doc.get("phaseC_gate", ""):
        problems.append("implementation gate must remain closed")
    ideas = doc.get("concepts")
    if not isinstance(ideas, list) or len(ideas) != 100:
        return ["expected exactly 100 Construction Phase-B ideas"]
    ids, titles, scenarios, domains = set(), set(), set(), {}
    for index, c in enumerate(ideas):
        prefix = f"record {index + 1}"
        if not isinstance(c, dict):
            problems.append(prefix + ": invalid object")
            continue
        missing = REQUIRED - c.keys()
        if missing:
            problems.append(prefix + ": missing " + ",".join(sorted(missing)))
            continue
        ident = f"EB-B-{index + 11:03d}"
        if c["id"] != ident or c["id"] in ids:
            problems.append(prefix + ": wrong/duplicate ID")
        ids.add(c["id"])
        title = str(c["title"]).strip().casefold()
        if len(title) < 12 or title in titles or any(x in title for x in PHASE_A_BUILDER):
            problems.append(prefix + ": duplicate/invalid title")
        titles.add(title)
        scenario = str(c["player_scenario"]).strip().casefold()
        if len(scenario) < 75 or scenario in scenarios:
            problems.append(prefix + ": empty/duplicate player scenario")
        scenarios.add(scenario)
        if c["domain"] not in DOMAINS:
            problems.append(prefix + ": unexpected domain")
        domains[c["domain"]] = domains.get(c["domain"], 0) + 1
        if c["status"] != "specified_not_implemented":
            problems.append(prefix + ": unverified implementation claim")
        if len(str(c["novelty_audit"])) < 120:
            problems.append(prefix + ": insufficient novelty audit")
        if not isinstance(c["player_verbs"], list) or len(c["player_verbs"]) < 5:
            problems.append(prefix + ": missing direct player verbs")
        if len(c["simulation_rules"]) < 3 or len(c["command_contract"]) < 3:
            problems.append(prefix + ": missing rule/command contracts")
        schema = c["state_schema"]
        if schema.get("version") != 1 or len(schema.get("fields", [])) < 5:
            problems.append(prefix + ": invalid state schema")
        controls = c["controls"]
        if not all(len(str(controls.get(k, ""))) > 45 for k in ("mouse_keyboard", "gamepad", "touch")):
            problems.append(prefix + ": missing accessible device controls")
        perf = c["performance_budget"]
        if not all("unmeasured" in str(perf.get(k, "")) or "pending" in str(perf.get(k, "")) for k in ("desktop", "mobile")):
            problems.append(prefix + ": unverified performance claim")
        if len(c["godot_acceptance"]) < 2 or len(c["adversarial_tests"]) < 2:
            problems.append(prefix + ": insufficient acceptance")
        if "Godot 4.x" not in c["engine_portability"] or "Unreal/Unity" not in c["engine_portability"]:
            problems.append(prefix + ": missing engine-port boundary")
        if not isinstance(c["dependencies"], list) or len(c["dependencies"]) < 2:
            problems.append(prefix + ": missing dependencies")
        econ = c["economy_and_resource_contract"]
        costs = econ.get("resource_inputs", {})
        if not isinstance(costs, dict) or not costs or any(
            type(v) is not int or v <= 0 for v in costs.values()
        ):
            problems.append(prefix + ": invalid finite material cost")
        if "CLOSED" not in c["phaseC_gate"]:
            problems.append(prefix + ": premature implementation")
        if len(c["original_asset_plan"]) < 2:
            problems.append(prefix + ": asset provenance absent")
    if set(domains) != DOMAINS or any(count != 10 for count in domains.values()):
        problems.append("expected ten distinct ideas in each of ten domains")
    return problems

def self_test(document):
    mutations = [
        ("duplicate ID", lambda d: d["concepts"][1].__setitem__("id", d["concepts"][0]["id"])),
        ("duplicate title", lambda d: d["concepts"][1].__setitem__("title", d["concepts"][0]["title"])),
        ("duplicate scenario", lambda d: d["concepts"][1].__setitem__("player_scenario", d["concepts"][0]["player_scenario"])),
        ("missing touch", lambda d: d["concepts"][0]["controls"].pop("touch")),
        ("empty cost", lambda d: d["concepts"][0]["economy_and_resource_contract"].__setitem__("resource_inputs", {})),
        ("negative cost", lambda d: d["concepts"][0]["economy_and_resource_contract"].__setitem__("resource_inputs", {"wood": -5})),
        ("fake implementation", lambda d: d["concepts"][0].__setitem__("status", "implemented")),
        ("early migration", lambda d: d.__setitem__("engine", "Unreal Engine 5")),
        ("open phase gate", lambda d: d.__setitem__("phaseC_gate", "OPEN")),
        ("missing state", lambda d: d["concepts"][0]["state_schema"].__setitem__("fields", [])),
        ("missing acceptance", lambda d: d["concepts"][0].__setitem__("godot_acceptance", [])),
        ("wrong domain", lambda d: d["concepts"][0].__setitem__("domain", "misc")),
        ("missing provenance", lambda d: d["concepts"][0].__setitem__("original_asset_plan", [])),
        ("missing dependencies", lambda d: d["concepts"][0].__setitem__("dependencies", [])),
        ("wrong count", lambda d: d["concepts"].pop()),
    ]
    for label, change in mutations:
        variant = copy.deepcopy(document)
        change(variant)
        if not check(variant):
            raise AssertionError("validator failed to reject " + label)
    return len(mutations)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    doc = json.loads(PATH.read_text(encoding="utf-8"))
    failures = check(doc)
    if failures:
        raise SystemExit("PHASE B CONSTRUCTION INVALID:\n" + "\n".join(failures))
    print("PHASE B CONSTRUCTION SPECIFICATION VALID: 100 IDs, 10 domains, no implementation claims")
    if args.self_test:
        count = self_test(doc)
        print(f"PHASE B ADVERSARIAL VALIDATOR: {count} invalid mutations detected, 0 failures")

if __name__ == "__main__":
    main()
