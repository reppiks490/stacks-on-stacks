#!/usr/bin/env python3
"""E03/E09/E18: strict exploration design-state audit; NOT Godot gameplay proof."""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

PATH = Path(__file__).with_name("navigation_051_060.json")
SAFE_MAX = 9007199254740991
SOURCE = {
    "EB-E-051": ["marker_ids", "bearings", "visibility_epoch", "route_receipt"],
    "EB-E-052": ["cave_id", "opening_window", "charted_rooms", "exit_reservation"],
    "EB-E-053": ["snow_cells", "footwear_id", "route_steps", "habitat_alerts"],
    "EB-E-054": ["call_ids", "route_nodes", "visited_edges", "overlook_flag"],
    "EB-E-055": ["outcrop_ids", "strata_notes", "confidence", "path_hint"],
    "EB-E-056": ["wind_epoch", "leaf_vectors", "clue_cells", "discovery"],
    "EB-E-057": ["pool_id", "depth_samples", "route_points", "shore_anchor"],
    "EB-E-058": ["spore_nodes", "glow_window", "trail_progress", "grove_found"],
    "EB-E-059": ["anchor_id", "tether_length", "wind_epoch", "sketch_cells"],
    "EB-E-060": ["historic_map", "route_nodes", "consent_ids", "opening_receipt"],
}


def typed(value, spec):
    if value is None:
        return spec.get("nullable") is True
    kind = spec.get("type")
    if kind == "string":
        return type(value) is str and spec["min_length"] <= len(value) <= spec["max_length"]
    if kind == "integer":
        return type(value) is int and spec["min"] <= value <= min(spec["max"], SAFE_MAX)
    if kind == "boolean":
        return type(value) is bool
    if kind == "enum":
        return type(value) is str and value in spec["values"]
    if kind == "object":
        fields = spec["fields"]
        return type(value) is dict and set(value) == set(fields) and all(
            typed(value[k], sub) for k, sub in fields.items())
    if kind == "list":
        if type(value) is not list or len(value) > spec["max_items"]:
            return False
        if not all(typed(x, spec["items"]) for x in value):
            return False
        unique = spec.get("unique_by")
        if unique:
            keys = [json.dumps(x, sort_keys=True) if unique == "$value" else x[unique]
                    for x in value]
            return len(keys) == len(set(keys))
        return True
    return False


def invariants(feature_id, s):
    n = int(feature_id[-3:])
    if n == 51:
        if not s["marker_ids"]:
            return (not s["bearings"] and s["visibility_epoch"] == -1
                    and s["route_receipt"] is None and s["route_epoch"] == -1)
        return (len(s["marker_ids"]) == len(s["bearings"]) == 3
                and s["visibility_epoch"] >= 1
                and all(b["marker_id"] in s["marker_ids"] for b in s["bearings"])
                and ((s["route_receipt"] is None and s["route_epoch"] == -1)
                     or (s["route_receipt"] is not None
                         and s["route_epoch"] >= s["visibility_epoch"])))
    if n == 52:
        if not s["cave_id"]:
            return (s["opening_window"] is None and not s["charted_rooms"]
                    and s["exit_reservation"] is None and not s["player_inside"]
                    and s["safe_exit_anchor"] == "" and s["return_epoch"] == -1)
        w, e = s["opening_window"], s["exit_reservation"]
        return (w is not None and e is not None and w["end_minute"] > w["start_minute"]
                and bool(s["safe_exit_anchor"]) and e["anchor_id"] == s["safe_exit_anchor"]
                and e["valid_until_epoch"] >= w["epoch"]
                and (e["valid_until_epoch"] > w["epoch"]
                     or e["valid_until_minute"] >= w["end_minute"])
                and (not s["player_inside"] or s["return_epoch"] == -1))
    if n == 53:
        if not s["footwear_id"]:
            return (not s["snow_cells"] and not s["route_steps"]
                    and not s["habitat_alerts"] and s["stamina_spent"] == 0)
        cells = {c["cell_id"]: c for c in s["snow_cells"]}
        return (bool(cells)
                and all(t["cell_id"] in cells and
                        not cells[t["cell_id"]]["protected_burrow"]
                        for t in s["route_steps"])
                and s["stamina_spent"] == sum(t["stamina_cost"]
                    for t in s["route_steps"] if t["stepped"])
                and all(x in cells and cells[x]["protected_burrow"]
                        for x in s["habitat_alerts"]))
    if n == 54:
        if not s["call_ids"]:
            return (not s["route_nodes"] and not s["visited_edges"]
                    and not s["overlook_flag"] and s["discovery_receipt"] is None
                    and s["visual_fallback"])
        nodes = {x["node_id"] for x in s["route_nodes"]}
        edges = [(x["from"], x["to"]) for x in s["visited_edges"]]
        return (len(s["call_ids"]) >= 3 and len(nodes) >= 3 and s["visual_fallback"]
                and all(x["call_id"] in s["call_ids"] for x in s["route_nodes"])
                and all(a != b and a in nodes and b in nodes for a, b in edges)
                and len(edges) == len(set(edges))
                and (not s["overlook_flag"] or
                     (len(edges) >= 2 and s["discovery_receipt"] is not None))
                and (s["discovery_receipt"] is None or s["overlook_flag"]))
    if n == 55:
        if not s["outcrop_ids"]:
            return (not s["strata_notes"] and s["confidence"] == "unknown"
                    and s["path_hint"] == "" and s["hint_region"] == ""
                    and s["unlock_receipt"] is None)
        if not all(x["outcrop_id"] in s["outcrop_ids"] for x in s["strata_notes"]):
            return False
        if s["confidence"] == "verified":
            return (len(s["strata_notes"]) >= 2 and bool(s["path_hint"])
                    and bool(s["hint_region"]) and s["unlock_receipt"] is not None)
        return (s["unlock_receipt"] is None and s["path_hint"] == ""
                and s["hint_region"] == "")
    if n == 56:
        if s["wind_epoch"] == -1:
            return (not s["leaf_vectors"] and not s["clue_cells"]
                    and not s["discovery"] and s["seed"] == 0
                    and s["discovery_receipt"] is None)
        cells = {x["cell_id"] for x in s["leaf_vectors"]}
        return (s["wind_epoch"] >= 1 and len(cells) >= 3
                and all(x in cells for x in s["clue_cells"])
                and ((s["discovery"] and len(s["clue_cells"]) >= 3
                      and s["discovery_receipt"] is not None)
                     or (not s["discovery"] and s["discovery_receipt"] is None)))
    if n == 57:
        if not s["pool_id"]:
            return (not s["depth_samples"] and not s["route_points"]
                    and s["shore_anchor"] == "" and not s["safe_return"]
                    and s["survey_epoch"] == -1)
        samples = {x["waypoint"]: x for x in s["depth_samples"]}
        return (s["survey_epoch"] >= 1 and len(samples) >= 2
                and all(x["epoch"] == s["survey_epoch"] for x in s["depth_samples"])
                and ((not s["route_points"] and not s["safe_return"])
                     or (bool(s["route_points"]) and bool(s["shore_anchor"])
                         and s["safe_return"]
                         and all(x in samples and samples[x]["depth_cm"] <= 60
                                 for x in s["route_points"]))))
    if n == 58:
        if not s["spore_nodes"]:
            return (s["glow_window"] is None and not s["trail_progress"]
                    and not s["grove_found"] and s["reward_receipt"] is None
                    and s["discovery_epoch"] == -1)
        w = s["glow_window"]
        glowing = {x["node_id"] for x in s["spore_nodes"] if x["glow"]}
        return (len(s["spore_nodes"]) >= 3 and w is not None
                and w["end_minute"] > w["start_minute"]
                and all(x in glowing for x in s["trail_progress"])
                and ((s["grove_found"]
                      and len(s["trail_progress"]) == len(s["spore_nodes"])
                      and s["reward_receipt"] is not None
                      and s["discovery_epoch"] == w["epoch"])
                     or (not s["grove_found"] and s["reward_receipt"] is None
                         and s["discovery_epoch"] == -1)))
    if n == 59:
        if not s["anchor_id"]:
            return (s["tether_length"] == 0 and s["wind_epoch"] == -1
                    and not s["sketch_cells"] and s["camera_region"] == ""
                    and s["launch_receipt"] is None)
        return (s["tether_length"] > 0 and s["wind_epoch"] >= 1
                and s["camera_region"] == "public_valley"
                and all(not x["privacy_zone"] for x in s["sketch_cells"])
                and (not s["sketch_cells"] or s["launch_receipt"] is not None))
    if n == 60:
        if not s["historic_map"]:
            return (not s["route_nodes"] and not s["consent_ids"]
                    and not s["required_consent_ids"] and s["opening_receipt"] is None
                    and not s["path_open"] and s["approval_epoch"] == -1)
        return (len(s["route_nodes"]) >= 2
                and (not s["path_open"]
                     or (s["opening_receipt"] is not None
                         and s["approval_epoch"] >= 1
                         and bool(s["required_consent_ids"])
                         and all(x in s["consent_ids"] for x in s["required_consent_ids"])
                         and all(x["land_status"] != "protected"
                                 for x in s["route_nodes"])))
                and (s["path_open"]
                     or (s["opening_receipt"] is None and s["approval_epoch"] == -1)))
    return False


def valid_state(contract, state):
    try:
        fields = contract["fields"]
        return (type(state) is dict and set(state) == set(fields)
                and all(typed(state[k], spec) for k, spec in fields.items())
                and invariants(contract["id"], state))
    except (KeyError, TypeError, ValueError, OverflowError):
        return False


def reject_constant(value):
    raise ValueError("Nonfinite JSON constant: " + value)


def load_catalog():
    with PATH.open(encoding="utf-8") as stream:
        return json.load(stream, parse_constant=reject_constant)


def validate_catalog(doc):
    assert doc["status"] == "design_only_non_authorizing"
    assert doc["phaseC"].startswith("closed_")
    assert doc["source"]["commit"] == "63cab5d05c742c61205933482e38fac2a4086764"
    assert doc["source"]["blob_sha"] == "eb7c590f43c92ded0e328ecfdf7003fa7c06ceac"
    contracts = doc["state_contracts"]
    assert len(contracts) == 10 and {x["id"] for x in contracts} == set(SOURCE)
    assert len({x["title"] for x in contracts}) == 10
    assert len({x["save_namespace"] for x in contracts}) == 10
    for c in contracts:
        assert c["phase"] == "design_only_no_runtime_implementation"
        assert c["source_fields"] == SOURCE[c["id"]]
        assert set(c["source_fields"] + c["additions"]) == set(c["fields"])
        assert len(c["rule_codes"]) == len(set(c["rule_codes"])) == 4
        assert c["state_version"] == 1
        assert len(c["positive_fixtures"]) == 2 and len(c["negative_cases"]) >= 4
        assert all(c.get(k) for k in ("authority", "migration", "controls", "native_gate",
                                     "performance_budget", "player_verbs", "dependencies"))
        assert all(typed(copy.deepcopy(spec["default"]), spec)
                   for spec in c["fields"].values())


def run_self_test():
    doc = load_catalog()
    validate_catalog(doc)
    positive = negative = roundtrips = 0
    for c in doc["state_contracts"]:
        for fixture in c["positive_fixtures"]:
            state = fixture["state"]
            assert valid_state(c, state), (c["id"], fixture["name"], "valid fixture rejected")
            positive += 1
            encoded = json.dumps(state, sort_keys=True, allow_nan=False)
            restored = json.loads(encoded, parse_constant=reject_constant)
            assert restored == state and valid_state(c, restored)
            roundtrips += 1
        active = next(x["state"] for x in c["positive_fixtures"] if x["name"] == "active")
        for case in c["negative_cases"]:
            hostile = copy.deepcopy(active)
            hostile.update(copy.deepcopy(case["patch"]))
            assert not valid_state(c, hostile), (c["id"], case["name"], "hostile accepted")
            negative += 1
        for key, spec in c["fields"].items():
            hostile = copy.deepcopy(active)
            hostile[key] = {"forged": True}
            assert not valid_state(c, hostile), (c["id"], key, "wrong type accepted")
            negative += 1
            if spec["type"] == "integer":
                hostile = copy.deepcopy(active)
                hostile[key] = True
                assert not valid_state(c, hostile), (c["id"], key, "boolean as integer")
                negative += 1
                hostile[key] = SAFE_MAX + 1
                assert not valid_state(c, hostile), (c["id"], key, "unsafe integer")
                negative += 1
            if spec["type"] == "list" and spec.get("unique_by") == "$value":
                items = active[key]
                if items:
                    hostile = copy.deepcopy(active)
                    hostile[key] = [items[0], items[0]]
                    assert not valid_state(c, hostile), (c["id"], key, "duplicate list")
                    negative += 1
        hostile = copy.deepcopy(active)
        hostile["forged_authority_field"] = "extra"
        assert not valid_state(c, hostile), (c["id"], "extra key")
        negative += 1
        hostile = copy.deepcopy(active)
        del hostile[next(iter(c["fields"]))]
        assert not valid_state(c, hostile), (c["id"], "missing key")
        negative += 1
    try:
        json.loads('{"counter": NaN}', parse_constant=reject_constant)
    except ValueError:
        negative += 1
    else:
        raise AssertionError("Nonfinite JSON accepted")
    print("PASS: 10 E051-E060 design contracts, %d valid fixtures, %d hostile cases "
          "rejected, %d deterministic JSON roundtrips; Phase C closed."
          % (positive, negative, roundtrips))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        run_self_test()
    else:
        validate_catalog(load_catalog())
        print("PASS: 10 design schemas structurally valid; use --self-test for hostile fixtures")


if __name__ == "__main__":
    main()
