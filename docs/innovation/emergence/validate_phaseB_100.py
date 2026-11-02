#!/usr/bin/env python3
"""EVERBLOOM Emergence Phase-B catalog integrity and adversarial audit.

This checks DESIGN SPECIFICATIONS ONLY. It does not execute new gameplay.
Offline stdlib-only; no external API, network, Codex, or purchased services.
"""
from __future__ import annotations

import argparse
import copy
import json
import re
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).parent
PARTS = (ROOT / "phaseB_011_050.json", ROOT / "phaseB_051_110.json")
DOMAINS = {
    "causal_world", "biome_stewardship", "social_agency",
    "regional_exchange", "exploration_navigation", "companion_intelligence",
    "ritual_culture", "creative_experiments", "sky_mystery",
    "cooperative_agency",
}
REQUIRED = {
    "id", "title", "domain", "mission_ids", "status", "novelty_audit",
    "player_scenario", "player_verbs", "simulation_rules", "state_schema",
    "command_contract", "service_contracts", "controls", "resource_accounting",
    "original_asset_plan", "performance_budget", "save_replay", "acceptance",
    "adversarial_tests", "engine_portability", "effort_estimate",
    "dependencies", "implementation_phases", "cross_loop_boundary", "phase_gate",
}
BAD_WORDS = {"todo", "tbd", "placeholder", "fixme", "n/a"}

def check(parts: list[dict]) -> list[str]:
    errors: list[str] = []
    if len(parts) != 2:
        return ["expected two Phase-B shard documents"]
    for index, part in enumerate(parts):
        if not isinstance(part, dict):
            return [f"part {index} is not an object"]
        if part.get("schema_version") != 1 or part.get("phase") != "B_additional_200":
            errors.append(f"part {index}: wrong schema/phase")
        if part.get("engine") != "Godot 4.x":
            errors.append(f"part {index}: premature engine migration")
        if "CLOSED" not in str(part.get("phaseC_gate", "")):
            errors.append(f"part {index}: Phase C gate opened")
        if "issuecomment-6573235593" not in str(part.get("phaseA_approval", "")):
            errors.append(f"part {index}: missing genuine Principal Phase-A approval")
    a, b = (part.get("concepts") for part in parts)
    if not isinstance(a, list) or not isinstance(b, list) or len(a) != 40 or len(b) != 60:
        return errors + ["expected 40 + 60 independently scoped Phase-B concepts"]
    entries = a + b
    ids, titles, scenarios, commands = set(), set(), set(), set()
    domains = Counter()
    for index, c in enumerate(entries):
        label = f"entry {index + 1}"
        if not isinstance(c, dict):
            errors.append(f"{label}: not an object")
            continue
        missing = REQUIRED - c.keys()
        if missing:
            errors.append(f"{label}: missing {sorted(missing)}")
            continue
        expected = f"EB-E-{index + 11:03d}"
        if c["id"] != expected or c["id"] in ids:
            errors.append(f"{label}: wrong or duplicate ID")
        ids.add(c["id"])
        title = str(c["title"]).strip().casefold()
        scenario = str(c["player_scenario"]).strip().casefold()
        if len(title) < 15 or title in titles or title in BAD_WORDS:
            errors.append(f"{label}: duplicate/invalid title")
        if len(scenario) < 75 or scenario in scenarios or scenario in BAD_WORDS:
            errors.append(f"{label}: duplicate/invalid scenario")
        titles.add(title)
        scenarios.add(scenario)
        if c["domain"] not in DOMAINS:
            errors.append(f"{label}: invalid domain")
        domains[c["domain"]] += 1
        if c["status"] != "specified_not_implemented":
            errors.append(f"{label}: false implementation claim")
        if len(str(c["novelty_audit"])) < 140:
            errors.append(f"{label}: weak novelty audit")
        if not isinstance(c["mission_ids"], list) or "E03" not in c["mission_ids"]:
            errors.append(f"{label}: missing E03 ownership")
        verbs = c["player_verbs"]
        if not isinstance(verbs, list) or len(verbs) < 4 or len(set(verbs)) != len(verbs):
            errors.append(f"{label}: incomplete player verbs")
        if not isinstance(c["simulation_rules"], list) or len(c["simulation_rules"]) < 3:
            errors.append(f"{label}: insufficient simulation rules")
        schema = c["state_schema"]
        if not isinstance(schema, dict) or schema.get("version") != 1 or len(schema.get("fields", [])) < 4:
            errors.append(f"{label}: invalid versioned state")
        contracts = c["command_contract"]
        if not isinstance(contracts, list) or len(contracts) < 3:
            errors.append(f"{label}: missing command contracts")
        else:
            for command in contracts:
                if command in commands:
                    errors.append(f"{label}: duplicate command signature")
                commands.add(command)
        if not isinstance(c["service_contracts"], list) or len(c["service_contracts"]) < 2:
            errors.append(f"{label}: missing service authority")
        controls = c["controls"]
        if not isinstance(controls, dict) or not all(
            len(str(controls.get(k, ""))) > 50
            for k in ("keyboard_mouse", "controller", "touch", "accessibility")
        ):
            errors.append(f"{label}: missing accessible input profile")
        cost = c["resource_accounting"]
        if not isinstance(cost, dict) or any(
            type(cost.get(k)) is not int or cost[k] < 0
            for k in ("proposed_time_minutes", "proposed_energy_units")
        ) or "refund" not in cost:
            errors.append(f"{label}: invalid finite cost/refund")
        art = c["original_asset_plan"]
        if not isinstance(art, list) or len(art) < 2 or "provenance" not in " ".join(art).lower():
            errors.append(f"{label}: missing original asset provenance")
        perf = c["performance_budget"]
        if not isinstance(perf, dict) or perf.get("status") != "proposed_not_measured" or (
            type(perf.get("active_instances_cap")) is not int or perf["active_instances_cap"] <= 0
        ):
            errors.append(f"{label}: fabricated/invalid performance")
        if "two-year" not in str(c["save_replay"]):
            errors.append(f"{label}: missing long-run replay contract")
        acceptance = c["acceptance"]
        if not isinstance(acceptance, dict) or any(
            len(str(acceptance.get(k, ""))) < 40
            for k in ("positive", "adversarial", "integrated")
        ):
            errors.append(f"{label}: missing acceptance")
        if not isinstance(c["adversarial_tests"], list) or len(c["adversarial_tests"]) < 2:
            errors.append(f"{label}: missing negative tests")
        effort = c["effort_estimate"]
        if not isinstance(effort, dict) or effort.get("size") not in ("S", "M", "L", "XL") or not re.fullmatch(
            r"\d+-\d+", str(effort.get("estimated_engineering_days", ""))
        ):
            errors.append(f"{label}: invalid effort estimate")
        if not isinstance(c["dependencies"], list) or len(c["dependencies"]) < 3:
            errors.append(f"{label}: missing dependencies")
        if not isinstance(c["implementation_phases"], list) or len(c["implementation_phases"]) < 3:
            errors.append(f"{label}: missing staged implementation")
        if "Builder" not in str(c["cross_loop_boundary"]):
            errors.append(f"{label}: missing Builder ownership boundary")
        if "Phase C closed" not in str(c["phase_gate"]):
            errors.append(f"{label}: premature implementation gate")
        if "Godot 4.x" not in str(c["engine_portability"]) or "Unreal/Unity" not in str(c["engine_portability"]):
            errors.append(f"{label}: engine portability/approval absent")
    if set(domains) != DOMAINS or any(v != 10 for v in domains.values()):
        errors.append("expected exactly 10 distinct ideas in each of 10 domains")
    return errors

def mutations(parts: list[dict]) -> int:
    tests = [
        ("duplicate ID", lambda d: d[0]["concepts"][1].__setitem__("id", d[0]["concepts"][0]["id"])),
        ("duplicate title", lambda d: d[0]["concepts"][1].__setitem__("title", d[0]["concepts"][0]["title"])),
        ("duplicate scenario", lambda d: d[0]["concepts"][1].__setitem__("player_scenario", d[0]["concepts"][0]["player_scenario"])),
        ("missing concept", lambda d: d[1]["concepts"].pop()),
        ("wrong domain", lambda d: d[0]["concepts"][0].__setitem__("domain", "construction")),
        ("false implementation", lambda d: d[0]["concepts"][0].__setitem__("status", "implemented")),
        ("missing touch", lambda d: d[0]["concepts"][0]["controls"].pop("touch")),
        ("missing controller", lambda d: d[0]["concepts"][0]["controls"].pop("controller")),
        ("no state fields", lambda d: d[0]["concepts"][0]["state_schema"].__setitem__("fields", [])),
        ("no commands", lambda d: d[0]["concepts"][0].__setitem__("command_contract", [])),
        ("no simulation", lambda d: d[0]["concepts"][0].__setitem__("simulation_rules", [])),
        ("no acceptance", lambda d: d[0]["concepts"][0].__setitem__("acceptance", {})),
        ("no adversarial", lambda d: d[0]["concepts"][0].__setitem__("adversarial_tests", [])),
        ("negative energy", lambda d: d[0]["concepts"][0]["resource_accounting"].__setitem__("proposed_energy_units", -1)),
        ("false perf", lambda d: d[0]["concepts"][0]["performance_budget"].__setitem__("status", "measured_pass")),
        ("missing art", lambda d: d[0]["concepts"][0].__setitem__("original_asset_plan", [])),
        ("missing dependencies", lambda d: d[0]["concepts"][0].__setitem__("dependencies", [])),
        ("early migration", lambda d: d[0].__setitem__("engine", "Unreal Engine 5")),
        ("open phase gate", lambda d: d[0].__setitem__("phaseC_gate", "OPEN")),
        ("missing approval", lambda d: d[0].__setitem__("phaseA_approval", "none")),
    ]
    for name, mutate in tests:
        variant = copy.deepcopy(parts)
        mutate(variant)
        if not check(variant):
            raise AssertionError(f"Failed to reject {name}")
    return len(tests)

def cross_check(parts: list[dict], other_files: list[Path]) -> list[str]:
    current = [x for p in parts for x in p["concepts"]]
    external = []
    for path in other_files:
        d = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(d.get("concepts"), list):
            return [f"{path}: missing concepts"]
        external.extend(d["concepts"])
    all_ideas = current + external
    problems = []
    for field in ("id", "title"):
        vals = [str(x.get(field, "")).strip().casefold() for x in all_ideas]
        if len(vals) != len(set(vals)):
            problems.append(f"cross-catalog duplicate {field}")
    return problems

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--compare-catalog", action="append", type=Path, default=[])
    args = parser.parse_args()
    parts = [json.loads(path.read_text(encoding="utf-8")) for path in PARTS]
    errors = check(parts)
    if args.compare_catalog:
        errors.extend(cross_check(parts, args.compare_catalog))
    if errors:
        raise SystemExit("EMERGENCE PHASE-B INVALID:\n" + "\n".join(errors[:40]))
    print("EMERGENCE PHASE-B CATALOG PASS: 100 unique IDs E011..E110, 10 domains, 10 per domain, design-only")
    if args.compare_catalog:
        print(f"EMERGENCE CROSS-CATALOG EXACT ID/TITLE AUDIT PASS: {len(args.compare_catalog)} external catalogs")
    if args.self_test:
        n = mutations(parts)
        print(f"EMERGENCE PHASE-B ADVERSARIAL PASS: {n} invalid mutations rejected, 0 failures")
    print("PHASE C CLOSED: these are specifications, NOT implemented or native-tested new gameplay")

if __name__ == "__main__":
    main()
