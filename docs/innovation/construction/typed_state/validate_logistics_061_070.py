#!/usr/bin/env python3
"""Design-only B061-B070 typed-state and adversarial contract validation; not Godot gameplay."""
import argparse
import copy
import json
from pathlib import Path

DATA = Path(__file__).with_name("logistics_061_070.json")
MAX_EPOCH = 9007199254740991

class ContractError(ValueError):
    pass

def need(condition, message):
    if not condition:
        raise ContractError(message)

def load(path):
    def pairs(entries):
        out = {}
        for k, v in entries:
            need(k not in out, "duplicate JSON key " + k)
            out[k] = v
        return out
    def reject_constant(token):
        raise ContractError("nonfinite JSON " + token)
    return json.loads(Path(path).read_text(encoding="utf-8"),
                      object_pairs_hook=pairs, parse_constant=reject_constant)

def check_type(spec, obj, path):
    kind = spec["type"]
    if kind == "integer":
        need(type(obj) is int and spec["min"] <= obj <= spec["max"], path + ": bounded integer")
    elif kind == "boolean":
        need(type(obj) is bool, path + ": boolean")
    elif kind == "string":
        need(type(obj) is str and spec["min_length"] <= len(obj) <= spec["max_length"], path + ": string")
        need(not any(ord(c) < 32 or ord(c) == 127 for c in obj), path + ": control character")
    elif kind == "enum":
        need(type(obj) is str and obj in spec["values"], path + ": enum")
    elif kind == "object":
        need(type(obj) is dict and set(obj) == set(spec["fields"]), path + ": exact object shape")
        for key, child in spec["fields"].items():
            check_type(child, obj[key], path + "." + key)
    elif kind == "list":
        need(type(obj) is list and len(obj) <= spec["max_items"], path + ": list bound")
        for i, item in enumerate(obj):
            check_type(spec["items"], item, path + "[" + str(i) + "]")
        key = spec.get("unique_by")
        if key:
            ids = [item[key] for item in obj]
            need(all(type(x) is str and x for x in ids) and len(ids) == len(set(ids)),
                 path + ": nonempty unique nested identifiers")
    else:
        raise ContractError(path + ": unsupported type " + str(kind))

def check_rule(rule, s):
    track = s.get("trolley_track", [])
    cargo = s.get("cargo_id", {})
    trips = s.get("barrow_load", [])
    spills = s.get("spill_receipts", [])
    bins = s.get("bin_capacity", {})
    lots = s.get("material_lots", [])
    permit = s.get("permit_id", {})
    impact = s.get("impact_report", {})
    zones = s.get("staging_zones", [])
    routes = s.get("route_graph", {})
    orders = s.get("order_id", [])
    arrival = s.get("arrival_epoch", {})
    scaffolds = s.get("scaffold_nodes", [])
    crews = s.get("crew_positions", [])
    hazards = s.get("hazard_cells", [])
    readiness = s.get("crew_readiness", [])
    boom = s.get("boom_angle", {})
    weight = s.get("counterweight_mass", {})
    tarps = s.get("tarp_footprints", [])
    protected = s.get("protected_lots", [])
    segment = next((x for x in track if x["segment_id"] == cargo.get("segment_id")), None)
    tarp_map = {x["tarp_id"]: x for x in tarps}
    hazard_map = {x["cell_id"]: x for x in hazards}
    ready_cells = [(c, hazard_map.get(c["cell_id"])) for c in readiness if c["ready"]]
    active_staging = any(z["active"] for z in zones)
    approved = permit.get("status") == "approved"
    arrived = [o for o in orders if o["arrival_epoch"] >= 0]
    settled = [o for o in orders if o["settled"]]
    rules = {
        "lift_mass": lambda: cargo["mass_kg"] == cargo["moved_kg"] + cargo["remaining_kg"],
        "lift_segment": lambda: not cargo["cargo_id"] or segment is not None,
        "lift_anchor": lambda: cargo["moved_kg"] == 0 or (segment is not None and segment["anchored"]),
        "lift_capacity": lambda: cargo["moved_kg"] == 0 or (segment is not None and cargo["mass_kg"] <= segment["max_load_kg"]),
        "lift_effort": lambda: cargo["moved_kg"] == 0 or (segment is not None and
            cargo["effort_units"] * 100 >= cargo["mass_kg"] * (100 + segment["slope_pct"] + segment["friction_pct"])),
        "barrow_mass": lambda: all(t["mass_kg"] == t["delivered_kg"] + t["spilled_kg"] + t["remaining_kg"] for t in trips),
        "barrow_capacity": lambda: all(t["mass_kg"] <= t["capacity_kg"] for t in trips),
        "barrow_balance": lambda: all(t["delivered_kg"] == 0 or t["slope_pct"] + t["center_offset_cm"] <= 30 for t in trips),
        "barrow_receipts": lambda: all(t["spilled_kg"] == sum(r["lost_kg"] for r in spills if r["trip_id"] == t["trip_id"]) for t in trips),
        "barrow_links": lambda: all(r["trip_id"] in {t["trip_id"] for t in trips} for r in spills),
        "shed_mass": lambda: all(t["input_kg"] == t["remaining_kg"] + t["removed_kg"] + t["spoiled_kg"] for t in lots),
        "shed_volume": lambda: sum(t["volume_l"] for t in lots) <= bins["volume_l"],
        "shed_humidity": lambda: bins["humidity_pct"] <= 70 or bins["sealed"] or bins["protected_pct"] >= 50 or
            all(t["input_kg"] == 0 or t["spoiled_kg"] >= 1 for t in lots),
        "shed_density": lambda: all(t["input_kg"] <= t["volume_l"] * 2 for t in lots),
        "permit_setback": lambda: not approved or impact["setback_cm"] >= impact["required_setback_cm"],
        "permit_consent": lambda: not approved or not impact["heritage_protected"] or impact["community_consent"],
        "permit_receipt": lambda: not approved or bool(permit["id"] and permit["council_receipt"]),
        "permit_order": lambda: not approved or permit["approval_epoch"] >= impact["submitted_epoch"] >= 0,
        "permit_epoch": lambda: not approved or permit["approval_epoch"] <= s["day_epoch"],
        "staging_capacity": lambda: all(z["loaded_kg"] <= z["capacity_kg"] for z in zones),
        "staging_emergency": lambda: not active_staging or (routes["emergency_path_open"] and
            all(not z["blocks_emergency"] for z in zones if z["active"])),
        "staging_width": lambda: not active_staging or routes["minimum_width_cm"] >= 100,
        "staging_exits": lambda: not active_staging or routes["reachable_exits"] >= 1,
        "courier_epochs": lambda: all(o["dispatch_epoch"] <= o["scheduled_epoch"] and
            (o["arrival_epoch"] == -1 or o["scheduled_epoch"] <= o["arrival_epoch"]) for o in orders),
        "courier_closure": lambda: all(not o["road_closed"] or o["arrival_epoch"] < 0 or o["alternate_route"] for o in orders),
        "courier_receipts": lambda: all(o["arrival_epoch"] >= 0 and o["settlement_receipt"] for o in settled) and
            len({o["settlement_receipt"] for o in settled}) == len(settled),
        "courier_counts": lambda: arrival["arrived_count"] == len(arrived) and
            arrival["settled_count"] == len(settled) and
            arrival["last_arrival_epoch"] == max([-1] + [o["arrival_epoch"] for o in arrived]),
        "courier_future": lambda: all(o["arrival_epoch"] <= s["day_epoch"] for o in arrived),
        "scaffold_load": lambda: all(n["occupied_kg"] <= n["max_load_kg"] for n in scaffolds),
        "scaffold_brace": lambda: all(not n["installed"] or n["occupied_kg"] == 0 or n["braced"] for n in scaffolds),
        "scaffold_crew": lambda: all(c["node_id"] in {n["node_id"] for n in scaffolds if n["installed"]} for c in crews),
        "scaffold_removal": lambda: all(not n["removal_requested"] or
            (n["occupied_kg"] == 0 and not any(c["node_id"] == n["node_id"] for c in crews)) for n in scaffolds),
        "scaffold_occupied": lambda: all(n["installed"] or n["occupied_kg"] == 0 for n in scaffolds),
        "drill_light": lambda: all(h is not None and h["light_lux"] >= 80 for c, h in ready_cells),
        "drill_clutter": lambda: all(h is not None and h["clutter_pct"] <= 40 for c, h in ready_cells),
        "drill_fatigue": lambda: all(c["fatigue_pct"] <= 60 for c, h in ready_cells),
        "drill_cert": lambda: all(c["certified"] for c, h in ready_cells),
        "drill_review": lambda: all(h is not None and h["reviewed"] for c, h in ready_cells),
        "drill_reference": lambda: all(c["cell_id"] in hazard_map for c in readiness),
        "crane_capacity": lambda: boom["load_kg"] <= boom["capacity_kg"],
        "crane_moment": lambda: not boom["lifted"] or
            boom["load_kg"] * weight["load_arm_cm"] * 11 <= weight["mass_kg"] * weight["arm_cm"] * 10,
        "crane_angle": lambda: not boom["lifted"] or 20 <= boom["angle_deg"] <= 70,
        "crane_anchor": lambda: not boom["lifted"] or weight["anchored"],
        "crane_reach": lambda: not boom["lifted"] or boom["reach_cm"] <= 600 - 4 * boom["angle_deg"],
        "tarp_mass": lambda: all(l["input_kg"] == l["remaining_kg"] + l["spoiled_kg"] + l["removed_kg"] for l in protected),
        "tarp_area": lambda: all(sum(l["area_m2"] for l in protected if l["tarp_id"] == t["tarp_id"]) <= t["area_m2"] for t in tarps),
        "tarp_ties": lambda: all(t["tie_downs"] * 4 >= t["area_m2"] for t in tarps if
            any(l["tarp_id"] == t["tarp_id"] for l in protected)),
        "tarp_wind": lambda: all(l["remaining_kg"] == 0 or
            (l["tarp_id"] in tarp_map and tarp_map[l["tarp_id"]]["wind_rating"] >= l["storm_wind"]) for l in protected),
        "tarp_epoch": lambda: all(t["installed_epoch"] <= s["day_epoch"] for t in tarps),
        "tarp_reference": lambda: all(l["tarp_id"] in tarp_map for l in protected),
    }
    need(rule in rules, "unknown rule " + rule)
    need(rules[rule](), rule)

def check_state(contract, state):
    fields = contract["fields"]
    need(type(state) is dict and set(state) == set(fields), "exact state shape")
    for key, spec in fields.items():
        check_type(spec, state[key], contract["id"] + "." + key)
    need(len(state["receipts"]) == len(set(state["receipts"])), "duplicate local receipt")
    active = any(state[k] != spec["default"] for k, spec in fields.items()
                 if k not in ("site_id", "revision", "day_epoch", "receipts"))
    need(not active or (bool(state["site_id"]) and state["revision"] >= 1 and state["day_epoch"] >= 1),
         "orphan active state")
    for rule in contract["rules"]:
        check_rule(rule, state)

def reject(contract, state, label):
    try:
        check_state(contract, state)
    except ContractError:
        return
    raise AssertionError(contract["id"] + " accepted " + label)

def self_test(data):
    need(data["status"] == "design_only_non_authorizing" and data["phaseC"].startswith("closed"), "phase gate")
    contracts = data["state_contracts"]
    need(len(contracts) == 10 and [c["id"] for c in contracts] ==
         [f"EB-B-{n:03d}" for n in range(61, 71)], "exact B061-B070 roster")
    counts = {"valid": 0, "invalid_domain": 0, "invalid_common": 0, "roundtrip": 0}
    for c in contracts:
        need(c["save_namespace"] == "construction.eb_b_" + c["id"][-3:], "namespace")
        need(len(c["rules"]) >= 4 and len(c["invalid_examples"]) == len(c["rules"]), "test depth")
        need(len(c["player_verbs"]) >= 4 and set(c["input_contract"]) ==
             {"mouse_keyboard", "gamepad", "touch"}, "controls")
        need(len(c["original_asset_plan"]) >= 2 and bool(c["resource_inputs_unapproved"]), "assets/cost")
        valid = c["valid_example"]
        check_state(c, valid)
        counts["valid"] += 1
        variant = copy.deepcopy(valid)
        variant["revision"] = 2
        variant["day_epoch"] = 57
        check_state(c, variant)
        counts["valid"] += 1
        defaults = {k: copy.deepcopy(spec["default"]) for k, spec in c["fields"].items()}
        check_state(c, defaults)
        counts["valid"] += 1
        for state in (valid, variant):
            serialized = json.dumps(state, sort_keys=True, separators=(",", ":"), allow_nan=False)
            need(json.loads(serialized) == state, "JSON roundtrip")
            counts["roundtrip"] += 1
        for hostile in c["invalid_examples"]:
            need(hostile["rule"] in c["rules"], "unknown targeted rule")
            try:
                check_rule(hostile["rule"], hostile["state"])
            except ContractError as error:
                need(str(error) == hostile["rule"], "wrong targeted rule")
            else:
                raise AssertionError(c["id"] + " targeted mutation did not fail " + hostile["rule"])
            reject(c, hostile["state"], hostile["rule"])
            counts["invalid_domain"] += 1
        mutants = []
        def mutate(label, change):
            state = copy.deepcopy(valid)
            change(state)
            mutants.append((label, state))
        mutate("duplicate receipt", lambda s: s["receipts"].append("cmdA"))
        mutate("unknown top field", lambda s: s.update({"injected": 1}))
        mutate("boolean revision", lambda s: s.update({"revision": True}))
        mutate("negative revision", lambda s: s.update({"revision": -1}))
        mutate("fractional epoch", lambda s: s.update({"day_epoch": 1.5}))
        mutate("epoch overflow", lambda s: s.update({"day_epoch": MAX_EPOCH + 1}))
        mutate("control site", lambda s: s.update({"site_id": "site\nA"}))
        mutate("empty receipt", lambda s: s.update({"receipts": [""]}))
        mutate("receipt overflow", lambda s: s.update({"receipts": ["r" + str(i) for i in range(129)]}))
        mutate("missing site", lambda s: s.update({"site_id": ""}))
        mutate("missing revision", lambda s: s.update({"revision": 0}))
        mutate("inactive epoch", lambda s: s.update({"day_epoch": -1}))
        nested = next(k for k, spec in c["fields"].items() if spec["type"] in ("list", "object")
                      and k != "receipts")
        target = valid[nested][0] if isinstance(valid[nested], list) else valid[nested]
        def bad_nested_shape(s):
            obj = s[nested][0] if isinstance(s[nested], list) else s[nested]
            obj["forged"] = 1
        mutate("nested unknown key", bad_nested_shape)
        def bad_nested_type(s):
            obj = s[nested][0] if isinstance(s[nested], list) else s[nested]
            k = next(k for k, v in c["fields"][nested]["items"]["fields"].items()
                     if v["type"] == "integer") if isinstance(s[nested], list) else next(
                     k for k, v in c["fields"][nested]["fields"].items() if v["type"] == "integer")
            obj[k] = True
        mutate("nested bool as integer", bad_nested_type)
        if isinstance(valid[nested], list):
            mutate("nested duplicate ID", lambda s: s[nested].append(copy.deepcopy(s[nested][0])))
            mutate("nested list overflow", lambda s: s.update({nested: s[nested] * 17}))
        else:
            mutate("missing nested key", lambda s: s[nested].pop(next(iter(s[nested]))))
        for label, state in mutants:
            reject(c, state, label)
            counts["invalid_common"] += 1
    return counts

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=DATA)
    args = parser.parse_args()
    counts = self_test(load(args.data))
    print("B061-B070 offline logistics contract PASS:", counts,
          "invalid total", counts["invalid_domain"] + counts["invalid_common"])
    print("Design contracts only; NOT native Godot gameplay, global inventory authority or mobile input proof.")

if __name__ == "__main__":
    main()
