#!/usr/bin/env python3
"""Offline B051-B060 material-crafting state-contract adversarial tests; NOT playable Godot proof."""
import argparse
import copy
import json
from pathlib import Path

DATA = Path(__file__).with_name("material_051_060.json")
MAX_EPOCH = 9007199254740991


class ContractError(ValueError):
    pass


def need(ok, message):
    if not ok:
        raise ContractError(message)


def load(path):
    def pairs(items):
        result = {}
        for key, val in items:
            need(key not in result, "duplicate JSON object key: " + key)
            result[key] = val
        return result

    def constant(token):
        raise ContractError("nonfinite JSON: " + token)

    return json.loads(Path(path).read_text(encoding="utf-8"),
                      object_pairs_hook=pairs, parse_constant=constant)


def value(spec, item, path):
    kind = spec["type"]
    if kind == "integer":
        need(type(item) is int and spec["min"] <= item <= spec["max"], path + " integer")
    elif kind == "boolean":
        need(type(item) is bool, path + " boolean")
    elif kind == "string":
        need(type(item) is str and spec["min_length"] <= len(item) <= spec["max_length"],
             path + " string")
        need(not any(ord(ch) < 32 or ord(ch) == 127 for ch in item), path + " control character")
    elif kind == "enum":
        need(type(item) is str and item in spec["values"], path + " enum")
    elif kind == "object":
        need(type(item) is dict and set(item) == set(spec["fields"]), path + " object shape")
        for name, child in spec["fields"].items():
            value(child, item[name], path + "." + name)
    elif kind == "list":
        need(type(item) is list and len(item) <= spec["max_items"], path + " list length")
        for i, child in enumerate(item):
            value(spec["items"], child, path + "[" + str(i) + "]")
        if "unique_by" in spec:
            keys = [child[spec["unique_by"]] for child in item]
            need(len(keys) == len(set(keys)), path + " duplicate local ID")
    else:
        raise ContractError(path + " unsupported type: " + str(kind))


def check_rule(rule, s):
    # All numeric quantities are bounded integers. Cross-domain grants are NOT authorized here.
    batches = s.get("log_batches", [])
    kilns = s.get("kiln_batches", [])
    glass = s.get("glass_batches", [])
    cuts = s.get("cut_planes", [])
    fibers = s.get("fiber_batches", [])
    irons = s.get("iron_lots", [])
    plaster = s.get("plaster_batches", [])
    tiles = s.get("tile_molds", [])
    salvage = s.get("salvage_lots", [])
    grades = s.get("grade_scores", [])
    furniture = s.get("furniture_blueprints", [])
    joints = s.get("joinery_nodes", [])
    rules = {
        "sawmill_mass": lambda: all(b["input_kg"] == b["planks_kg"] + b["sawdust_kg"] + b["waste_kg"] for b in batches),
        "sawmill_feed": lambda: all(b["input_kg"] == 0 or 1 <= b["feed_mm"] <= 30 for b in batches),
        "sawmill_power": lambda: s["plank_yield"]["wheel_rpm"] <= s["plank_yield"]["water_flow_lps"] * 3 and (not any(b["planks_kg"] for b in batches) or s["plank_yield"]["wheel_rpm"] > 0),
        "sawmill_output": lambda: s["plank_yield"]["produced_kg"] == sum(b["planks_kg"] for b in batches),
        "kiln_mass": lambda: all(b["clay_kg"] == b["tile_kg"] + b["scrap_kg"] for b in kilns),
        "kiln_fuel": lambda: all(b["tile_kg"] == 0 or b["fuel_kg"] >= (b["clay_kg"] + 3) // 4 for b in kilns),
        "kiln_quality": lambda: s["heat_curve"]["quality_pct"] <= 60 or (s["heat_curve"]["cool_hours"] >= 12 and s["heat_curve"]["hold_hours"] >= 2 and all(b["moisture_pct"] <= 30 for b in kilns)),
        "kiln_epoch": lambda: all(0 <= b["firing_epoch"] <= s["day_epoch"] for b in kilns),
        "glass_mass": lambda: all(b["raw_kg"] == b["pane_kg"] + b["scrap_kg"] for b in glass),
        "glass_stress": lambda: all(b["stress_pct"] <= max(0, 50 - b["anneal_hours"] * 2) for b in glass),
        "glass_hours": lambda: s["anneal_ticks"]["total_hours"] >= max([s["anneal_ticks"]["min_hours"]] + [b["anneal_hours"] for b in glass]),
        "glass_release": lambda: (0 <= s["anneal_ticks"]["release_epoch"] <= s["day_epoch"]) if glass else s["anneal_ticks"]["release_epoch"] == -1,
        "stone_mass": lambda: all(b["input_kg"] == b["blocks_kg"] + b["offcuts_kg"] + b["dust_kg"] for b in cuts),
        "stone_depth": lambda: all(b["depth_cm"] <= 40 for b in cuts),
        "stone_offcuts": lambda: s["stone_offcuts"]["accounted_kg"] == sum(b["offcuts_kg"] for b in cuts) and s["stone_offcuts"]["reserved_kg"] <= s["stone_offcuts"]["accounted_kg"],
        "rope_mass": lambda: all(b["fiber_kg"] == b["rope_kg"] + b["waste_kg"] for b in fibers),
        "rope_grade": lambda: s["rope_grade"]["grade"] != "sturdy" or all(b["twist_per_m"] >= 10 for b in fibers),
        "rope_capacity": lambda: s["rope_grade"]["load_kg"] <= s["rope_grade"]["rated_kg"] <= sum(b["rope_kg"] for b in fibers) * 8,
        "forge_mass": lambda: all(b["input_kg"] == b["nails_kg"] + b["hinges_kg"] + b["brackets_kg"] + b["slag_kg"] for b in irons),
        "forge_fuel": lambda: all(b["fuel_units"] >= (b["input_kg"] + 3) // 4 for b in irons) and (not irons or s["hardware_recipe"]["forge_heat_c"] <= sum(b["fuel_units"] for b in irons) * 40),
        "forge_output": lambda: s["hardware_recipe"]["output_kg"] == sum(b["nails_kg"] + b["hinges_kg"] + b["brackets_kg"] for b in irons),
        "forge_wear": lambda: all(s["hardware_recipe"]["wear_after_pct"] >= b["tool_wear_pct"] for b in irons),
        "plaster_mass": lambda: all(b["wet_kg"] == b["applied_kg"] + b["waste_kg"] for b in plaster),
        "plaster_coat": lambda: all(b["coat_mm"] <= 20 for b in plaster),
        "plaster_moisture": lambda: s["finish_life"]["expected_days"] <= s["finish_life"]["max_days"] and (not any(b["substrate_moisture_pct"] > 35 for b in plaster) or s["finish_life"]["expected_days"] <= 14),
        "plaster_epoch": lambda: (0 <= s["finish_life"]["applied_epoch"] <= s["day_epoch"]) if plaster else s["finish_life"]["applied_epoch"] == -1,
        "tile_mass": lambda: all(b["clay_kg"] == b["tile_kg"] + b["scrap_kg"] for b in tiles),
        "tile_depth": lambda: all(b["emboss_mm"] <= min(s["emboss_depth"]["max_mm"], b["thickness_mm"] // 2) for b in tiles),
        "tile_cracks": lambda: s["emboss_depth"]["cracked_count"] == sum(b["emboss_mm"] * 3 > b["thickness_mm"] for b in tiles),
        "tile_total": lambda: s["emboss_depth"]["total_count"] == len(tiles),
        "salvage_mass": lambda: all(b["input_kg"] == b["reusable_kg"] + b["scrap_kg"] for b in salvage),
        "salvage_proof": lambda: all(g["lot_id"] in {b["lot_id"] for b in salvage if b["verified"]} for g in grades),
        "salvage_credit": lambda: all(g["credited_kg"] <= {b["lot_id"]: b["reusable_kg"] for b in salvage}.get(g["lot_id"], -1) for g in grades),
        "salvage_source": lambda: len({b["source_receipt"] for b in salvage}) == len(salvage),
        "furniture_mass": lambda: all(b["input_kg"] == b["parts_kg"] + b["offcut_kg"] for b in furniture),
        "furniture_refs": lambda: all(j["blueprint_id"] in {b["blueprint_id"] for b in furniture} for j in joints),
        "furniture_support": lambda: all(j["supported_kg"] >= j["required_kg"] and j["required_kg"] <= {b["blueprint_id"]: b["max_load_kg"] for b in furniture}.get(j["blueprint_id"], -1) for j in joints),
    }
    need(rule in rules, "unknown rule: " + rule)
    need(rules[rule](), rule)


def check_state(c, s):
    fields = c["fields"]
    need(type(s) is dict and set(s) == set(fields), "state shape")
    for name, spec in fields.items():
        value(spec, s[name], c["id"] + "." + name)
    need(len(s["receipts"]) == len(set(s["receipts"])), "duplicate local receipts")
    active = any(s[name] != spec["default"] for name, spec in fields.items()
                 if name not in ("site_id", "revision", "day_epoch", "receipts"))
    need(not active or (bool(s["site_id"]) and s["revision"] >= 1 and s["day_epoch"] >= 1),
         "orphan active state")
    for rule in c["rules"]:
        check_rule(rule, s)


def rejected(c, s, label):
    try:
        check_state(c, s)
    except ContractError:
        return
    raise AssertionError(c["id"] + " accepted invalid " + label)


def self_test(data):
    need(data["status"] == "design_only_non_authorizing" and data["phaseC"].startswith("closed"),
         "phase gate")
    contracts = data["state_contracts"]
    need(len(contracts) == 10, "exactly ten B051-B060")
    need([c["id"] for c in contracts] == [f"EB-B-{n:03d}" for n in range(51, 61)],
         "IDs must be consecutive")
    counts = {"valid": 0, "invalid_domain": 0, "invalid_common": 0, "roundtrip": 0}
    for c in contracts:
        need(c["save_namespace"] == "construction.eb_b_" + c["id"][-3:].lower(), "namespace")
        need(len(c["rules"]) >= 3 and len(c["invalid_examples"]) >= 3, "test depth")
        need(len(c["player_verbs"]) >= 4 and set(c["input_contract"]) == {"mouse_keyboard", "gamepad", "touch"}, "input parity design")
        need(len(c["original_asset_plan"]) >= 2 and bool(c["resource_inputs_unapproved"]), "assets and costs")
        valid = c["valid_example"]
        check_state(c, valid)
        counts["valid"] += 1
        variant = copy.deepcopy(valid)
        variant["revision"] = 2
        variant["day_epoch"] = 57
        check_state(c, variant)
        counts["valid"] += 1
        for s in (valid, variant):
            canonical = json.dumps(s, sort_keys=True, separators=(",", ":"), allow_nan=False)
            need(json.loads(canonical) == s, "JSON roundtrip")
            counts["roundtrip"] += 1
        defaults = {name: copy.deepcopy(spec["default"]) for name, spec in c["fields"].items()}
        check_state(c, defaults)
        counts["valid"] += 1
        for hostile in c["invalid_examples"]:
            need(hostile["rule"] in c["rules"], "invalid fixture rule exists")
            try:
                check_rule(hostile["rule"], hostile["state"])
            except ContractError as err:
                need(str(err) == hostile["rule"], "invalid case must fail its intended domain rule")
            else:
                raise AssertionError(c["id"] + " failed to trigger " + hostile["rule"])
            rejected(c, hostile["state"], hostile["rule"])
            counts["invalid_domain"] += 1
        mutants = []
        def mutate(label, change):
            state = copy.deepcopy(valid)
            change(state)
            mutants.append((label, state))
        mutate("duplicate receipt", lambda s: s["receipts"].append("cmdA"))
        mutate("unknown state field", lambda s: s.update({"untrusted": 1}))
        mutate("boolean revision", lambda s: s.update({"revision": True}))
        mutate("negative revision", lambda s: s.update({"revision": -1}))
        mutate("fractional epoch", lambda s: s.update({"day_epoch": 1.25}))
        mutate("overflow epoch", lambda s: s.update({"day_epoch": MAX_EPOCH + 1}))
        mutate("control character site", lambda s: s.update({"site_id": "site\\nA"}))
        mutate("empty receipt", lambda s: s.update({"receipts": [""]}))
        mutate("receipt overflow", lambda s: s.update({"receipts": ["x" + str(i) for i in range(129)]}))
        mutate("missing site", lambda s: s.update({"site_id": ""}))
        mutate("missing revision", lambda s: s.update({"revision": 0}))
        mutate("inactive epoch with active state", lambda s: s.update({"day_epoch": -1}))
        nested = next(k for k, v in c["fields"].items() if v["type"] == "list" and v.get("unique_by"))
        mutate("nested unknown field", lambda s: s[nested][0].update({"forged": 1}))
        mutate("nested duplicate ID", lambda s: s[nested].append(copy.deepcopy(s[nested][0])))
        def corrupt_int(s):
            row = s[nested][0]
            k = next(k for k, v in c["fields"][nested]["items"]["fields"].items() if v["type"] == "integer")
            row[k] = True
        mutate("nested bool as integer", corrupt_int)
        for label, state in mutants:
            rejected(c, state, label)
            counts["invalid_common"] += 1
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=DATA)
    args = parser.parse_args()
    data = load(args.data)
    counts = self_test(data)
    print("B051-B060 offline typed-state PASS:", counts,
          "total invalid", counts["invalid_domain"] + counts["invalid_common"])
    print("NOT native Godot gameplay, economy settlement, touch/device or migration proof.")


if __name__ == "__main__":
    main()
