#!/usr/bin/env python3
"""Read-only, offline Phase-A 20-feature cross-loop audit; NOT gameplay proof.

Run: python3 docs/innovation/construction/validate_phaseA_joint.py --self-test
Only frozen copies of immutable branch catalogs are audited. A Principal review
is still REQUIRED before Phase B or gameplay implementation may begin.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
CONTRACT = ROOT / "PHASEA_CROSS_LOOP_CONTRACT.json"
REQUIRED = (
    "id", "title", "domain", "status", "novelty_audit", "player_scenario",
    "player_verbs", "player_loop", "simulation_rules", "state_schema",
    "command_contract", "service_contracts", "controls", "original_asset_plan",
    "performance_budget", "godot_acceptance", "adversarial_tests",
    "engine_portability", "effort_estimate", "dependencies",
    "economy_and_resource_contract",
)
EXPECTED_EDGES = {
    ("EB-B-004", "EB-E-002"), ("EB-B-008", "EB-E-010"),
    ("EB-B-005", "EB-E-003"), ("EB-B-010", "EB-E-001"),
    ("EB-B-010", "EB-E-007"), ("EB-B-007", "EB-E-008"),
    ("EB-B-002", "EB-E-009"), ("EB-B-009", "EB-E-004"),
}
BAD_STRINGS = {"todo", "tbd", "placeholder", "later", "n/a", "fixme"}


def git_blob_sha(raw: bytes) -> str:
    return hashlib.sha1(b"blob " + str(len(raw)).encode() + b"\0" + raw).hexdigest()


def substantive(value: object) -> bool:
    if value is None or value == "" or value == [] or value == {}:
        return False
    if isinstance(value, str):
        return len(value.strip()) >= 3 and value.strip().casefold() not in BAD_STRINGS
    return True


def validate(c: dict, b: dict, e: dict) -> list[str]:
    errors: list[str] = []
    if c.get("schema_version") != 1 or c.get("phase") != "A_cross_loop_review":
        errors.append("invalid cross-loop contract version/phase")
    if c.get("status") != "candidate_pending_principal_acceptance":
        errors.append("Principal acceptance must not be invented")
    if c.get("engine") != "Godot 4.x" or c.get("implementation_gate") != 220:
        errors.append("Godot-first/220-feature gate broken")
    gates = c.get("phase_gate")
    if not isinstance(gates, dict) or not all(gates.get(k) is True for k in
        ("godot_first", "no_codex", "no_unapproved_spend", "no_engine_port_before_baseline")):
        errors.append("mandatory safety and engine gate missing")
    for label, catalog, prefix in (("Builder", b, "B"), ("Emergence", e, "E")):
        if not isinstance(catalog, dict) or catalog.get("phase") != "A_20_ideas":
            errors.append(f"{label}: wrong catalog phase")
            continue
        if catalog.get("target_engine") != "Godot 4.x" or "220" not in str(catalog.get("gate", "")):
            errors.append(f"{label}: implementation gate violated")
        items = catalog.get("concepts")
        if not isinstance(items, list) or len(items) != 10:
            errors.append(f"{label}: expected exactly 10 concepts")
            continue
        ids = [item.get("id") for item in items if isinstance(item, dict)]
        if len(ids) != 10 or set(ids) != {f"EB-{prefix}-{i:03d}" for i in range(1, 11)}:
            errors.append(f"{label}: IDs not exactly 001..010")
    items = b.get("concepts", []) + e.get("concepts", [])
    if len(items) != 20 or any(not isinstance(x, dict) for x in items):
        return errors + ["exactly 20 valid concept objects required"]
    if c.get("total_concepts") != len(items):
        errors.append("contract concept count does not match snapshot")
    for key in ("id", "title", "domain"):
        vals = [str(x.get(key, "")).strip().casefold() for x in items]
        if len(vals) != len(set(vals)):
            errors.append(f"cross-loop duplicate {key}")
    for index, item in enumerate(items):
        label = str(item.get("id", f"item[{index}]"))
        for field in REQUIRED:
            if not substantive(item.get(field)):
                errors.append(f"{label}: missing/placeholder {field}")
        if item.get("status") != "specified_pending_review":
            errors.append(f"{label}: unapproved implementation/acceptance claim")
        for field, minimum in (("player_verbs", 3), ("simulation_rules", 2),
                               ("command_contract", 2), ("service_contracts", 1),
                               ("original_asset_plan", 2), ("godot_acceptance", 3),
                               ("adversarial_tests", 2), ("dependencies", 2)):
            v = item.get(field)
            if not isinstance(v, list) or len(v) < minimum or not all(
                isinstance(s, str) and len(s.strip()) >= 3 for s in v
            ):
                errors.append(f"{label}: inadequate {field}")
        controls = item.get("controls")
        if not isinstance(controls, dict) or not all(
            isinstance(controls.get(k), str) and len(controls[k]) >= 24
            for k in ("mouse_keyboard", "gamepad", "touch")
        ):
            errors.append(f"{label}: missing multimodal controls")
        schema = item.get("state_schema")
        if not isinstance(schema, dict) or schema.get("version") != 1 or not (
            isinstance(schema.get("fields"), list) and len(schema["fields"]) >= 4
        ):
            errors.append(f"{label}: insufficient versioned persistence schema")
        budget = item.get("performance_budget")
        if not isinstance(budget, dict) or not all(
            isinstance(budget.get(k), str) and len(budget[k]) >= 30
            for k in ("desktop", "mobile")
        ):
            errors.append(f"{label}: missing device performance targets")
        economy = item.get("economy_and_resource_contract")
        if not isinstance(economy, dict) or not isinstance(economy.get("resource_inputs"), dict):
            errors.append(f"{label}: missing material ledger")
        else:
            for material, qty in economy["resource_inputs"].items():
                if not isinstance(material, str) or not material or type(qty) is not int or qty < 0:
                    errors.append(f"{label}: invalid material quantity")
            if not isinstance(economy.get("refund"), str) or len(economy["refund"]) < 20:
                errors.append(f"{label}: missing rollback/refund rule")
        if not isinstance(item.get("novelty_audit"), str) or len(item["novelty_audit"]) < 50:
            errors.append(f"{label}: weak novelty comparison")
    sources = c.get("source_branches")
    if not isinstance(sources, list) or len(sources) != 2:
        errors.append("both immutable source references required")
    else:
        roles = {s.get("role") for s in sources if isinstance(s, dict)}
        if roles != {"construction", "emergence"}:
            errors.append("source provenance roles invalid")
        for s in sources:
            if not isinstance(s, dict) or not re.fullmatch(r"[0-9a-f]{40}", str(s.get("commit", ""))):
                errors.append("source commit must be immutable 40-character SHA")
            if not isinstance(s, dict) or not re.fullmatch(r"[0-9a-f]{40}", str(s.get("git_blob_sha", ""))):
                errors.append("source blob must be immutable 40-character SHA")
    overlaps = c.get("overlaps")
    if not isinstance(overlaps, list) or len(overlaps) != 8:
        errors.append("exactly eight reviewed potential overlap boundaries required")
        return errors
    pairs = [(x.get("builder_id"), x.get("emergence_id")) for x in overlaps if isinstance(x, dict)]
    if len(pairs) != 8 or set(pairs) != EXPECTED_EDGES:
        errors.append("missing, duplicate or misassigned overlap boundary")
    for x in overlaps:
        if not isinstance(x, dict):
            errors.append("overlap must be an object")
            continue
        if x.get("approval") != "pending_principal_review":
            errors.append("overlap approval cannot be asserted by Builder")
        for key in ("title", "authority", "interface_contract", "invariant", "acceptance"):
            if not isinstance(x.get(key), str) or len(x[key]) < 45:
                errors.append(f"{x.get('id')}: insufficient {key}")
    authorities = c.get("global_authority")
    if not isinstance(authorities, list) or len(authorities) < 6:
        errors.append("cross-domain source-of-truth authority missing")
    return errors


def load_frozen() -> tuple[dict, dict, dict, list[str]]:
    c = json.loads(CONTRACT.read_text(encoding="utf-8"))
    catalogs: dict[str, dict] = {}
    errors: list[str] = []
    for source in c.get("source_branches", []):
        path = ROOT / source["snapshot"]
        raw = path.read_bytes()
        if git_blob_sha(raw) != source["git_blob_sha"]:
            errors.append(f"snapshot differs from immutable source: {source['role']}")
        catalogs[source["role"]] = json.loads(raw.decode("utf-8"))
    return c, catalogs["construction"], catalogs["emergence"], errors


def negative_tests(c: dict, b: dict, e: dict) -> int:
    cases = [
        ("duplicate concept ID", lambda a, x, y: y["concepts"][0].__setitem__("id", x["concepts"][0]["id"])),
        ("duplicate concept title", lambda a, x, y: y["concepts"][1].__setitem__("title", x["concepts"][0]["title"])),
        ("duplicate domain", lambda a, x, y: y["concepts"][1].__setitem__("domain", x["concepts"][0]["domain"])),
        ("missing touch mapping", lambda a, x, y: x["concepts"][0]["controls"].pop("touch")),
        ("missing acceptance", lambda a, x, y: x["concepts"][1].__setitem__("godot_acceptance", [])),
        ("negative resource", lambda a, x, y: x["concepts"][0]["economy_and_resource_contract"]["resource_inputs"].__setitem__("wood", -1)),
        ("missing save fields", lambda a, x, y: y["concepts"][0]["state_schema"].__setitem__("fields", [])),
        ("premature implementation", lambda a, x, y: x["concepts"][0].__setitem__("status", "implemented")),
        ("engine migration", lambda a, x, y: a.__setitem__("engine", "Unreal Engine 5")),
        ("premature Principal approval", lambda a, x, y: a["overlaps"][0].__setitem__("approval", "approved")),
        ("deleted overlap", lambda a, x, y: a["overlaps"].pop()),
        ("missing material authority", lambda a, x, y: a.__setitem__("global_authority", [])),
        ("weakened 220 gate", lambda a, x, y: a.__setitem__("implementation_gate", 20)),
    ]
    for name, change in cases:
        a, x, y = copy.deepcopy((c, b, e))
        change(a, x, y)
        if not validate(a, x, y):
            raise AssertionError(f"Failed to detect negative case: {name}")
    return len(cases)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    contract, builder, emergence, provenance_errors = load_frozen()
    errors = provenance_errors + validate(contract, builder, emergence)
    if errors:
        for error in errors:
            print("PHASE-A AUDIT ERROR:", error)
        return 1
    n = negative_tests(contract, builder, emergence) if args.self_test else 0
    print(f"PHASE-A CROSS-LOOP MECHANICAL AUDIT PASS: 20 original specs, 8 boundary contracts, {n} adversarial mutations detected, 0 errors.")
    print("Original Git blob SHA of each immutable source catalog verified.")
    print("PRINCIPAL APPROVAL: PENDING. PHASE B: BLOCKED. PHASE C: BLOCKED.")
    print("This audits design documents only, NOT playable Godot construction or emergence.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
