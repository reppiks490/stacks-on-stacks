#!/usr/bin/env python3
"""B091-B100 design-only tooling contracts: strict typed and hostile verification.

No Godot gameplay, authoritative inventory transaction, or save integration.
"""
from __future__ import annotations

import copy
import json
import random
import re
from pathlib import Path

DATA = Path(__file__).with_name("tooling_091_100.json")
EXPECTED = [f"EB-B-{n:03d}" for n in range(91, 101)]


class InvalidState(ValueError):
    pass


def require(condition, reason):
    if not condition:
        raise InvalidState(reason)


def unique(values, reason):
    require(len(values) == len(set(values)), reason)


def typed(value, schema, path="state"):
    kind = schema["type"]
    if kind == "object":
        require(type(value) is dict, f"{path}:not_object")
        props = schema["properties"]
        require(set(schema["required"]) <= set(value), f"{path}:missing")
        if schema.get("additional_properties") is False:
            require(set(value) <= set(props), f"{path}:unknown")
        for key, item in value.items():
            require(key in props, f"{path}:unknown_field")
            typed(item, props[key], f"{path}.{key}")
    elif kind == "array":
        require(type(value) is list and len(value) <= schema["max_items"], f"{path}:array")
        for i, item in enumerate(value):
            typed(item, schema["items"], f"{path}[{i}]")
        if schema.get("unique_items"):
            unique([json.dumps(x, sort_keys=True, allow_nan=False) for x in value], f"{path}:duplicate")
        if schema.get("unique_by"):
            unique([x[schema["unique_by"]] for x in value], f"{path}:duplicate_id")
    elif kind == "integer":
        require(type(value) is int and schema["min"] <= value <= schema["max"], f"{path}:integer")
    elif kind == "boolean":
        require(type(value) is bool, f"{path}:boolean")
    elif kind == "string":
        require(type(value) is str and schema["min_length"] <= len(value) <= schema["max_length"],
                f"{path}:string")
    else:
        raise InvalidState(f"{path}:unsupported_type")


def domain_rule(n, s):
    if n == 91:
        require(s["graph_revision"] == s["revision"], "stale_graph")
        nodes = {v["id"]: v for v in s["nodes"]}
        require(len(nodes) > 0 and all(v["installed"] for v in nodes.values()), "installed_nodes")
        for node in nodes.values():
            require(node["id"] not in node["depends_on"] and
                    all(d in nodes for d in node["depends_on"]), "invalid_dependency")
        visiting, visited = set(), set()
        def visit(node_id):
            require(node_id not in visiting, "cycle")
            if node_id in visited:
                return
            visiting.add(node_id)
            for dep in nodes[node_id]["depends_on"]:
                visit(dep)
            visiting.remove(node_id)
            visited.add(node_id)
        for node_id in nodes:
            visit(node_id)
        leaves = {x for x in nodes if not any(x in v["depends_on"] for v in nodes.values())}
        require(set(s["safe_removals"]) == leaves, "unsafe_removal")
        require(set(s["dependent_ids"]) == leaves, "stale_dependents")
    elif n == 92:
        require(re.fullmatch(r"[0-9a-f]{64}", s["mesh_digest"]) is not None, "mesh_digest")
        faces = {v["id"]: v for v in s["faces"]}
        require(bool(faces), "faces")
        pairs = []
        for p in s["intersection_pairs"]:
            require(p["a"] in faces and p["b"] in faces and p["a"] != p["b"], "face_ref")
            pairs.append(tuple(sorted((p["a"], p["b"]))))
        unique(pairs, "duplicate_pair")
        affected = {f for p in pairs for f in p}
        require(set(s["repair_face_ids"]) == affected, "incomplete_repair")
        require(s["watertight"] == (not pairs and all(f["manifold"] for f in faces.values())),
                "watertight_mismatch")
    elif n == 93:
        lots = {v["id"]: v for v in s["lots"]}
        require(s["source_lot"] in lots and all(v["verified"] for v in lots.values()), "lot_authority")
        require(all(1 <= v["grade"] <= 5 for v in lots.values()), "lot_grade")
        require(bool(s["part_passports"]), "passport_required")
        for p in s["part_passports"]:
            require(p["lot_id"] in lots and p["grade"] <= lots[p["lot_id"]]["grade"] and
                    p["repairs"] <= 3, "passport_provenance")
        unique([p["receipt_id"] for p in s["part_passports"]], "duplicate_passport_receipt")
    elif n == 94:
        d = s["pattern_def"]
        require(d["immutable"] and d["spacing_mm"] > 0 and d["span_mm"] > 0 and
                d["span_mm"] % d["spacing_mm"] == 0, "immutable_quantized_pattern")
        require(s["instance_count"] == len(s["instance_transforms"]), "phantom_instance")
        positions = []
        for i in s["instance_transforms"]:
            require(i["paid"] and i["x_mm"] <= d["span_mm"] and
                    i["x_mm"] % d["spacing_mm"] == 0 and
                    i["rotation_deg"] % 90 == 0 and i["rotation_deg"] < 360, "invalid_instance")
            positions.append(i["x_mm"])
        unique(positions, "overlapping_instances")
    elif n == 95:
        m = s["measurement"]
        dx, dy = abs(m["x2_cm"] - m["x1_cm"]), abs(m["y2_cm"] - m["y1_cm"])
        require((dx == 0) != (dy == 0), "non_axis_aligned")
        require(s["dimension_cm"] == dx + dy and 0 <= s["tolerance_mm"] <= 10,
                "dimension_drift")
    elif n == 96:
        criteria = {c["id"]: c["passed"] for c in s["criteria_results"]}
        require(set(criteria) == {"ventilation", "egress", "weatherproof"}, "missing_criterion")
        cert = s["certificate"]
        require(cert["active"] == all(criteria.values()), "false_certification")
        require(cert["source_revision"] == s["revision"] and
                cert["expiry_epoch"] >= s["day_epoch"], "stale_certificate")
        require(s["certificate_id"].startswith("cert-"), "certificate_id")
    elif n == 97:
        require(bool(s["load_cases"]), "no_virtual_loads")
        margins = [c["capacity"] - c["virtual_load"] for c in s["load_cases"]]
        require(all(c["capacity"] > 0 and c["virtual_load"] <= c["capacity"]
                    for c in s["load_cases"]), "overloaded_virtual_test")
        require(s["stress_margin"] == min(margins) and s["safe"] and
                s["structure_mutation_count"] == 0, "virtual_only_margin")
    elif n == 98:
        q = s["demolition_quote"]
        require(s["quote_revision"] == s["revision"] and
                s["salvage_grade"] <= 100 and
                q["salvage_wood"] <= q["source_wood"], "stale_or_impossible_quote")
        require(q["labor_cost"] > 0, "zero_labor")
        if not q["confirmed_removed"]:
            require(q["credited_salvage"] == 0 and q["refund_receipt"] == "none",
                    "preview_must_not_refund")
        else:
            require(q["credited_salvage"] <= q["salvage_wood"] and
                    q["refund_receipt"] != "none", "unproven_salvage")
    elif n == 99:
        events = s["event_receipts"]
        require(bool(events), "empty_chronicle")
        require(all(0 < v["revision"] <= s["revision"] and v["epoch"] <= s["day_epoch"]
                    for v in events), "future_event")
        require(all(events[i]["revision"] < events[i + 1]["revision"] and
                    events[i]["epoch"] <= events[i + 1]["epoch"]
                    for i in range(len(events) - 1)), "out_of_order_event")
        require(s["revision_index"] == events[-1]["revision"] and
                s["milestone_ids"] == [v["id"] for v in events], "invented_milestone")
    elif n == 100:
        profiles = s["actor_profiles"]
        routes = s["routes"]
        require(bool(profiles) and bool(routes), "missing_actor_or_route")
        require(all(p["width_cm"] > 0 for p in profiles), "invalid_actor_width")
        require(all(r["width_cm"] > 0 for r in routes), "invalid_route_width")
        expected = []
        for p in profiles:
            safe_count = 0
            for route in routes:
                reason = ("width" if route["width_cm"] < p["width_cm"] else
                          "step" if route["step_cm"] > p["max_step_cm"] else "")
                if reason:
                    expected.append((p["id"], route["id"], reason))
                else:
                    safe_count += 1
            require(safe_count > 0, "actor_softlock")
        actual = [(x["actor_id"], x["route_id"], x["reason"]) for x in s["route_failures"]]
        require(sorted(actual) == sorted(expected), "inaccurate_route_failures")
    else:
        raise InvalidState("unrecognized_feature")


def validate(record, state):
    typed(state, record["save_contract"]["schema"])
    domain_rule(int(record["id"][-3:]), state)


def changed(state, path, value):
    clone = copy.deepcopy(state)
    node = clone
    for segment in path[:-1]:
        node = node[segment]
    node[path[-1]] = value
    return clone


def leaves(value, path=()):
    if type(value) is dict:
        for key, item in value.items():
            yield from leaves(item, path + (key,))
    elif type(value) is list:
        for index, item in enumerate(value):
            yield from leaves(item, path + (index,))
    else:
        yield path, value


def wrong_type(value, rng):
    if type(value) is bool:
        return rng.choice([0, None, "true"])
    if type(value) is int:
        return rng.choice([True, -1, "invalid", None])
    if type(value) is str:
        return rng.choice(["", None, 42])
    return None


def expect_invalid(record, state, label):
    try:
        validate(record, state)
    except (InvalidState, ValueError, TypeError, KeyError, OverflowError):
        return
    raise AssertionError(f"{record['id']} accepted invalid {label}")


def run():
    payload = json.loads(DATA.read_text(encoding="utf-8"))
    records = payload["state_contracts"]
    require([r["id"] for r in records] == EXPECTED, "wrong_roster")
    require(payload["source_blob"] == "d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b",
            "unfrozen_catalog")
    require(payload["phaseC"].startswith("CLOSED"), "phase_gate")
    unique([r["save_contract"]["namespace"] for r in records], "duplicate_namespace")
    rng = random.Random(20261102)
    valid = hostile = common = fuzz = roundtrips = epochs = 0
    for record in records:
        n = int(record["id"][-3:])
        require(record["status"] == "typed_design_only_not_playable", "false_status")
        require(record["save_contract"]["namespace"] == f"construction.eb_b_{n:03d}",
                "namespace")
        require(len(record["valid_fixtures"]) == 2 and
                len(record["hostile_mutations"]) >= 4, "missing_fixtures")
        require(len(record["source_field_mapping"]) == 2, "source_field_mapping")
        require(all(k in record["save_contract"]["schema"]["properties"]
                    for k in record["source_field_mapping"]), "source_field_not_typed")
        require(set(record["controls"]) >= {"mouse_keyboard", "gamepad", "touch"},
                "missing_input_contract")
        require(bool(record["original_asset_plan"]) and bool(record["acceptance"]) and
                bool(record["dependencies"]), "missing_feature_contract")
        first, second = record["valid_fixtures"]
        require(first["day_epoch"] == 56 and second["day_epoch"] == 112 and
                second["day_epoch"] - first["day_epoch"] == 56, "two_year_epoch")
        epochs += 1
        for fixture in record["valid_fixtures"]:
            validate(record, fixture)
            valid += 1
            encoded = json.dumps(fixture, sort_keys=True, separators=(",", ":"), allow_nan=False)
            decoded = json.loads(encoded)
            validate(record, decoded)
            require(decoded == fixture, "json_roundtrip")
            roundtrips += 1
            for m in record["hostile_mutations"]:
                expect_invalid(record, changed(fixture, m["path"], m["value"]), m["name"])
                hostile += 1
            cases = [
                ("missing_site", {k: copy.deepcopy(v) for k, v in fixture.items()
                                  if k != "site_id"}),
                ("unknown_field", dict(fixture, injected_field=1)),
                ("duplicate_receipt", changed(fixture, ["receipts"],
                                              [fixture["receipts"][0]] * 2)),
                ("negative_revision", changed(fixture, ["revision"], -1)),
                ("boolean_epoch", changed(fixture, ["day_epoch"], True)),
                ("nan_revision", changed(fixture, ["revision"], float("nan"))),
                ("malformed_receipts", changed(fixture, ["receipts"], {"bad": 1})),
                ("invalid_nested", changed(fixture, [list(record["source_field_mapping"])[0]],
                                            None)),
            ]
            for label, bad in cases:
                expect_invalid(record, bad, label)
                common += 1
            options = list(leaves(fixture))
            for _ in range(16):
                path, value = rng.choice(options)
                expect_invalid(record, changed(fixture, path, wrong_type(value, rng)),
                               "seeded_type_fuzz")
                fuzz += 1
    print(f"TOOLING_CONTRACTS={len(records)} VALID={valid} HOSTILE_REJECTED={hostile} "
          f"COMMON_REJECTED={common} SEEDED_FUZZ_REJECTED={fuzz} "
          f"ROUNDTRIPS={roundtrips} TWO_YEAR_EPOCH_CHECKS={epochs}")
    print("DESIGN_ONLY=TRUE NATIVE_GODOT_GAMEPLAY_PROOF=FALSE")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
