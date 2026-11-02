#!/usr/bin/env python3
"""Strict offline ecological landscape design-contract validator (B041-B050); not playable Godot proof."""
import argparse
import copy
import json
import math
from pathlib import Path

DATA = Path(__file__).with_name("ecology_041_050.json")
MAX_EPOCH = 9007199254740991


class ContractError(ValueError):
    pass


def need(condition, reason):
    if not condition:
        raise ContractError(reason)


def load(path):
    def reject_constant(value):
        raise ContractError("nonfinite JSON constant " + value)
    return json.loads(Path(path).read_text(encoding="utf-8"), parse_constant=reject_constant)


def value(spec, item, where):
    kind = spec["type"]
    if kind == "integer":
        need(type(item) is int and spec["min"] <= item <= spec["max"], where + " integer bounds")
    elif kind == "boolean":
        need(type(item) is bool, where + " bool")
    elif kind == "string":
        need(type(item) is str and spec["min_length"] <= len(item) <= spec["max_length"], where + " string bounds")
        need(not any(ord(ch) < 32 for ch in item), where + " control character")
    elif kind == "enum":
        need(type(item) is str and item in spec["values"], where + " enum")
    elif kind == "object":
        need(type(item) is dict and set(item) == set(spec["fields"]), where + " object shape")
        for name, child in spec["fields"].items():
            value(child, item[name], where + "." + name)
    elif kind == "list":
        need(type(item) is list and len(item) <= spec["max_items"], where + " list size")
        for index, child in enumerate(item):
            value(spec["items"], child, where + "[" + str(index) + "]")
        if "unique_by" in spec:
            keys = [child[spec["unique_by"]] for child in item]
            need(len(keys) == len(set(keys)), where + " duplicate list key")
    else:
        raise ContractError(where + " unknown type " + str(kind))


def check_rule(rule, s):
    if rule == "terrace_slope_and_cut":
        need(all(x["slope_permille"] <= 350 and x["cut_cm"] <= 80 for x in s["terrace_steps"]), "excess slope or cut")
    elif rule == "terrace_root_references":
        roots = {x["root_id"] for x in s["root_buffers"]}
        need(all(x["root_id"] in roots for x in s["terrace_steps"]), "orphan root")
    elif rule == "terrace_root_exclusion":
        roots = {x["root_id"]: x for x in s["root_buffers"]}
        need(all(not roots[x["root_id"]]["protected"] or
                 x["root_distance_cm"] >= roots[x["root_id"]]["radius_cm"] + 50
                 for x in s["terrace_steps"]), "terrace intrudes on protected roots")
    elif rule == "hedge_shadow_refs":
        ids = {x["hedge_id"] for x in s["hedge_segments"]}
        need(all(x["hedge_id"] in ids for x in s["wind_shadow"]), "orphan wind shadow")
    elif rule == "hedge_maturity_bound":
        hedges = {x["hedge_id"]: x for x in s["hedge_segments"]}
        need(all(x["reduction_pct"] <= min(80, hedges[x["hedge_id"]]["age_days"] * 2,
                                         100 - hedges[x["hedge_id"]]["porosity_pct"])
                 for x in s["wind_shadow"]), "unearned wind reduction")
    elif rule == "hedge_exposure_conservation":
        need(all(x["exposure_pct"] + x["reduction_pct"] == 100
                 for x in s["wind_shadow"]), "wind exposure not conserved")
    elif rule == "ford_depth_and_gap":
        need(all(not x["safe"] or (x["depth_cm"] <= 40 and x["gap_cm"] <= 90)
                 for x in s["stone_positions"]), "unsafe marked-safe stepping stone")
    elif rule == "ford_flood_closure":
        f = s["flow_limit"]
        need(f["flood_closed"] == (f["current_lps"] > f["max_safe_lps"]), "flood closure inconsistent")
    elif rule == "ford_closed_safety":
        need(not s["flow_limit"]["flood_closed"] or
             all(not x["safe"] for x in s["stone_positions"]), "safe crossing during closure")
    elif rule == "fish_step_geometry":
        need(all(x["rise_cm"] <= 30 and x["basin_depth_cm"] >= 20
                 for x in s["ladder_steps"]), "impassable fish step")
    elif rule == "fish_flow_conservation":
        f = s["flow_split"]
        need(f["inflow_lps"] == f["mill_lps"] + f["ladder_lps"] + f["spill_lps"], "invented fish passage water")
    elif rule == "fish_bypass_total":
        need(s["flow_split"]["ladder_lps"] == sum(x["bypass_lps"] for x in s["ladder_steps"]),
             "fish ladder bypass mismatch")
    elif rule == "basin_cell_conservation":
        need(all(x["incoming_l"] == x["infiltration_l"] + x["stored_l"] + x["overflow_l"]
                 for x in s["basin_cells"]), "basin water lost or created")
    elif rule == "basin_capacity":
        need(all(x["stored_l"] <= x["capacity_l"] for x in s["basin_cells"]), "basin overfilled")
    elif rule == "basin_outlet_conservation":
        o = s["overflow_outlet"]
        need(o["inflow_l"] == sum(x["incoming_l"] for x in s["basin_cells"]) and
             o["released_l"] == sum(x["overflow_l"] for x in s["basin_cells"]) and
             o["released_l"] <= o["max_release_l"], "basin outlet ledger mismatch")
    elif rule == "privy_mass_conservation":
        need(all(x["input_kg"] == x["treated_kg"] + x["waste_kg"]
                 for x in s["treatment_chambers"]), "fictional compost mass created")
    elif rule == "privy_maturity_gate":
        c = s["compost_grade"]
        if c["releasable_kg"] > 0:
            need(c["grade"] != "none" and
                 all(x["stage"] == "mature" for x in s["treatment_chambers"]) and
                 c["releasable_kg"] <= sum(x["treated_kg"] for x in s["treatment_chambers"]),
                 "immature or excess compost release")
        else:
            need(c["grade"] == "none", "grade without releasable compost")
    elif rule == "privy_epoch_gate":
        c = s["compost_grade"]
        need(all(x["last_turn_epoch"] <= s["day_epoch"] for x in s["treatment_chambers"]),
             "future chamber maintenance")
        if c["releasable_kg"] > 0:
            need(0 <= c["release_epoch"] <= s["day_epoch"] and
                 all(x["last_turn_epoch"] <= c["release_epoch"] for x in s["treatment_chambers"]),
                 "invalid compost release day")
        else:
            need(c["release_epoch"] == -1, "inactive release epoch")
    elif rule == "roof_load_and_depth":
        need(all(5 <= x["depth_cm"] <= 60 and x["wet_kg"] <= x["support_kg"]
                 for x in s["roof_soil_depth"]), "living roof unsupported")
    elif rule == "roof_wet_mass":
        need(all(x["dry_kg"] <= x["wet_kg"] for x in s["roof_soil_depth"]),
             "wet roof soil lighter than dry soil")
    elif rule == "roof_drainage_conservation":
        d = s["drainage"]
        need(d["inflow_l"] == d["outflow_l"] + d["retained_l"] and
             d["retained_l"] <= d["capacity_l"], "living roof water ledger mismatch")
    elif rule == "mill_wind_speed":
        need(all(x["rpm"] <= x["wind_kph"] * 4 for x in s["paddle_speed"]),
             "windless mill spinning")
    elif rule == "mill_gear_bound":
        need(all(x["rpm"] <= x["gear_health_pct"] * 2 for x in s["paddle_speed"]),
             "damaged gear overspeed")
    elif rule == "mill_oxygen_conservation":
        o = s["oxygen_index"]
        need(o["final_ppm"] == o["initial_ppm"] + o["delta_ppm"] and
             o["final_ppm"] <= o["upper_ppm"] and
             o["delta_ppm"] <= sum(x["rpm"] for x in s["paddle_speed"]) // 10,
             "unearned pond oxygen")
    elif rule == "fence_sediment_conservation":
        need(all(x["upstream_kg"] == x["trapped_kg"] + x["downstream_kg"]
                 for x in s["fence_rows"]), "sediment mass not conserved")
    elif rule == "fence_capture_capacity":
        need(all(x["trapped_kg"] <= x["max_capture_kg"] for x in s["fence_rows"]),
             "sediment capture over capacity")
    elif rule == "fence_authoritative_debit":
        c = s["sediment_captured"]
        need(c["total_trapped_kg"] == sum(x["trapped_kg"] for x in s["fence_rows"]) and
             c["upstream_debit_kg"] == sum(x["upstream_kg"] for x in s["fence_rows"]),
             "missing upstream sediment debit")
        need((0 <= c["day_epoch"] <= s["day_epoch"]) if c["total_trapped_kg"] else
             c["day_epoch"] == -1, "sediment settlement epoch")
    elif rule == "deck_support_capacity":
        need(all(x["load_kg"] <= x["capacity_kg"] and
                 (x["load_kg"] == 0 or x["anchored"]) for x in s["deck_supports"]),
             "unsupported treehouse deck")
    elif rule == "deck_trunk_sway":
        t = s["trunk_clearance"]
        need(all(x["clearance_cm"] >= t["min_clearance_cm"] + t["tree_sway_cm"] + x["sway_cm"]
                 for x in s["deck_supports"]), "treehouse deck collides with swaying trunk")
    elif rule == "deck_root_buffer":
        t = s["trunk_clearance"]
        need(all(x["root_distance_cm"] >= t["required_root_buffer_cm"]
                 for x in s["deck_supports"]), "treehouse pier injures roots")
    else:
        raise ContractError("unimplemented domain rule: " + rule)


def check_state(c, state):
    fields = c["fields"]
    need(type(state) is dict and set(state) == set(fields), c["id"] + " state shape")
    for name, spec in fields.items():
        value(spec, state[name], c["id"] + "." + name)
    need(len(state["receipts"]) == len(set(state["receipts"])), "duplicate local receipts")
    active = any(state[name] != spec["default"] for name, spec in fields.items()
                 if name not in ("site_id", "revision", "day_epoch", "receipts"))
    need(not active or (bool(state["site_id"]) and state["revision"] >= 1 and state["day_epoch"] >= 1), "orphan active state")
    for rule in c["rules"]:
        check_rule(rule, state)


def reject(c, state, reason):
    try:
        check_state(c, state)
    except ContractError:
        return
    raise AssertionError(c["id"] + " incorrectly accepted " + reason)


def self_test(data):
    contracts = data["state_contracts"]
    need(len(contracts) == 10 and [c["id"] for c in contracts] ==
         ["EB-B-%03d" % n for n in range(41, 51)], "wrong ecological landscape tranche")
    need(len({c["save_namespace"] for c in contracts}) == 10, "namespace collision")
    good = bad = 0
    for c in contracts:
        need(set(c["source_fields"]) == set(c["fields"]), "source fields drift")
        need(len(c["rules"]) >= 2 and len(c["invalid_examples"]) >= 3, "insufficient domain cases")
        need(c["native_gate"].startswith("Not tested in native Godot"), "false native claim")
        example = c["valid_example"]
        check_state(c, example)
        need(json.loads(json.dumps(example, allow_nan=False)) == example, "JSON roundtrip drift")
        inactive = {k: copy.deepcopy(v["default"]) for k, v in c["fields"].items()}
        check_state(c, inactive)
        good += 2
        for index, case in enumerate(c["invalid_examples"]):
            try:
                check_rule(c["rules"][index], case["state"])
            except ContractError:
                pass
            else:
                raise AssertionError(c["id"] + " targeted rule not exercised: " + c["rules"][index])
            reject(c, case["state"], case["reason"])
            bad += 1
        for field in ("revision", "day_epoch"):
            corrupt = copy.deepcopy(example)
            corrupt[field] = True
            reject(c, corrupt, "bool masquerading as integer")
            bad += 1
        for field in ("revision", "day_epoch"):
            corrupt = copy.deepcopy(example)
            corrupt[field] = -999
            reject(c, corrupt, "underflow")
            bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["receipts"].append("cmdA")
        reject(c, corrupt, "duplicate command receipt")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["unknown_field"] = 1
        reject(c, corrupt, "unknown field")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["site_id"] = ""
        reject(c, corrupt, "orphan active state")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["revision"] = 0
        reject(c, corrupt, "uncommitted active state")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["day_epoch"] = 0
        reject(c, corrupt, "nonpositive active epoch")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["receipts"].append(chr(0))
        reject(c, corrupt, "control-character receipt")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["receipts"] = ["x"] * 129
        reject(c, corrupt, "receipt bound")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["revision"] = float("nan")
        reject(c, corrupt, "NaN revision")
        bad += 1
        corrupt = copy.deepcopy(example)
        corrupt["revision"] = 9007199254740992
        reject(c, corrupt, "revision overflow")
        bad += 1
    print("ECOLOGY DESIGN CONTRACTS PASS: %d valid fixtures, %d invalid fixtures rejected, 10 distinct rule sets; native gameplay NOT tested" % (good, bad))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=DATA)
    args = parser.parse_args()
    self_test(load(args.data))


if __name__ == "__main__":
    main()
