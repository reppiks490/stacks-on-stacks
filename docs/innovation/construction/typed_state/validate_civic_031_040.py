#!/usr/bin/env python3
"""Strict offline civic design-contract validator (B031-B040); not playable Godot proof."""
import argparse
import copy
import json
import math
from pathlib import Path

DATA = Path(__file__).with_name("civic_031_040.json")
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
    if rule == "bridge_load_support":
        need(all(x["load_kg"] <= min(x["left_capacity_kg"], x["right_capacity_kg"]) for x in s["bridge_spans"]), "unsupported span")
    elif rule == "bridge_river_clearance":
        need(all(x["clearance_cm"] >= 150 for x in s["bridge_spans"]), "bridge obstructs river clearance")
    elif rule == "council_authorization":
        v = s["council_vote"]
        need(v["status"] == "approved" or (v["approval_epoch"] == -1 and v["approved_revision"] == 0), "stale council approval")
        if v["status"] == "approved":
            need(bool(s["bridge_spans"]) and all(x["certified"] for x in s["bridge_spans"]), "uncertified approved span")
            need(0 <= v["approval_epoch"] <= s["day_epoch"] and v["approved_revision"] == s["revision"], "invalid approval epoch/revision")
    elif rule == "walkway_nodes":
        need(all(x["from_node"] != x["to_node"] and x["width_cm"] >= 90 for x in s["walkway_segments"]), "self link or narrow walkway")
    elif rule == "habitat_pier_exclusion":
        for x in s["walkway_segments"]:
            for n in s["nesting_buffer"]:
                distance_sq = (x["pier_x_cm"]-n["x_cm"])**2 + (x["pier_z_cm"]-n["z_cm"])**2
                need(distance_sq >= (n["radius_cm"]+50)**2, "pier inside nest protection zone")
    elif rule == "hall_capacity":
        need(all(x["occupied"] <= x["capacity"] for x in s["hall_zones"]), "zone overcrowded")
    elif rule == "hall_egress":
        exits = {x["exit_id"]: x for x in s["exit_graph"]}
        need(all(x["exit_id"] in exits and exits[x["exit_id"]]["open"] for x in s["hall_zones"] if x["occupied"] > 0), "unreachable closed exit")
        need(sum(x["occupied"] for x in s["hall_zones"]) <= sum(x["capacity"] for x in s["exit_graph"] if x["open"]), "insufficient open egress")
    elif rule == "hall_exit_throughput":
        need(all(x["capacity"] <= x["width_cm"] * 2 for x in s["exit_graph"]), "exit capacity exceeds width")
    elif rule == "storm_stall_fold":
        need(all(x["folded"] or x["wind_kph"] <= 50 for x in s["stall_modules"]), "unfolded stall in storm")
    elif rule == "vendor_slot_refs":
        ids = {x["stall_id"] for x in s["stall_modules"]}
        need(all(x["stall_id"] in ids and x["start_min"] < x["end_min"] for x in s["vendor_slots"]), "invalid vendor slot")
    elif rule == "vendor_time_exclusive":
        slots = s["vendor_slots"]
        for i, a in enumerate(slots):
            for b in slots[i+1:]:
                overlap = a["start_min"] < b["end_min"] and b["start_min"] < a["end_min"]
                need(not (overlap and (a["stall_id"] == b["stall_id"] or a["vendor_id"] == b["vendor_id"])), "vendor or stall double-booked")
    elif rule == "lantern_tank_refs":
        ids = {x["tank_id"] for x in s["fuel_tanks"]}
        need(all(x["tank_id"] in ids for x in s["lantern_nodes"]), "orphan lantern tank")
        need(all(x["remaining_ml"] <= x["capacity_ml"] for x in s["fuel_tanks"]), "tank over capacity")
    elif rule == "fuel_burn_budget":
        for tank in s["fuel_tanks"]:
            debit = sum(x["fuel_burn_ml"] for x in s["lantern_nodes"] if x["tank_id"] == tank["tank_id"] and x["lit"])
            need(debit <= tank["remaining_ml"], "lantern fuel overspent")
    elif rule == "lantern_visibility":
        need(all((x["lit"] and x["fuel_burn_ml"] > 0 and 0 < x["visibility_cm"] <= 1000)
                 or (not x["lit"] and x["fuel_burn_ml"] == 0 and x["visibility_cm"] == 0) for x in s["lantern_nodes"]), "impossible lantern visibility")
    elif rule == "shelter_wind_rating":
        need(all(not x["usable"] or x["wind_rating_kph"] >= x["forecast_kph"] for x in s["shelter_anchors"]), "unrated shelter")
    elif rule == "shelter_capacity":
        need(all(x["occupants"] <= x["seats"] and (x["usable"] or x["occupants"] == 0) for x in s["shelter_anchors"]), "shelter overfilled/unusable")
    elif rule == "shelter_totals":
        need(s["capacity"]["total_seats"] == sum(x["seats"] for x in s["shelter_anchors"] if x["usable"]), "shelter seat total drift")
        need(s["capacity"]["protected_occupants"] == sum(x["occupants"] for x in s["shelter_anchors"] if x["usable"]), "shelter occupancy total drift")
    elif rule == "harvest_consent":
        plots = {x["plot_id"]: x for x in s["plot_owners"]}
        need(all(x["plot_id"] in plots and x["actor_id"] == plots[x["plot_id"]]["owner_id"]
                 and bool(plots[x["plot_id"]]["consent_receipt"]) for x in s["harvest_receipts"]), "harvest lacks consent")
    elif rule == "harvest_quota":
        for plot in s["plot_owners"]:
            used = sum(x["quantity"] for x in s["harvest_receipts"] if x["plot_id"] == plot["plot_id"])
            need(used <= plot["harvest_quota"], "harvest exceeds quota")
    elif rule == "harvest_epoch":
        plots = {x["plot_id"]: x for x in s["plot_owners"]}
        need(all(x["consent_epoch"] <= s["day_epoch"] for x in s["plot_owners"]), "future consent")
        need(all(x["day_epoch"] <= s["day_epoch"] and x["plot_id"] in plots and
                 x["day_epoch"] >= plots[x["plot_id"]]["consent_epoch"] for x in s["harvest_receipts"]), "harvest outside consent window")
    elif rule == "station_occupancy":
        need(all(x["occupancy"] <= x["capacity"] and (x["open"] or x["occupancy"] == 0) for x in s["waystation_ids"]), "waystation overcrowded")
    elif rule == "route_endpoint_refs":
        ids = {x["station_id"] for x in s["waystation_ids"]}
        need(all(x["from_station"] in ids and x["to_station"] in ids and x["from_station"] != x["to_station"] for x in s["route_links"]), "invalid route endpoint")
    elif rule == "route_open_endpoints":
        stations = {x["station_id"]: x for x in s["waystation_ids"]}
        need(all(not x["active"] or (stations[x["from_station"]]["open"] and stations[x["to_station"]]["open"]) for x in s["route_links"]), "active route with closed station")
    elif rule == "sign_destination_refs":
        nodes = {x["node_id"] for x in s["sign_graph"]}
        need(all(x["destination_id"] in nodes and x["destination_id"] != x["node_id"] for x in s["sign_graph"]), "unreachable sign destination")
    elif rule == "sign_translation_refs":
        keys = {x["key"] for x in s["language_keys"]}
        need(all(x["language_key"] in keys for x in s["sign_graph"]), "sign missing translation")
    elif rule == "sign_locale_pair":
        seen = [(x["key"], x["locale"]) for x in s["language_keys"]]
        need(len(seen) == len(set(seen)), "duplicate localized string")
        keys = {x["language_key"] for x in s["sign_graph"]}
        need(all({(k, "en"), (k, "es")} <= set(seen) for k in keys), "missing bilingual sign")
    elif rule == "class_capacity":
        need(all(x["occupied"] <= x["capacity"] and (x["occupied"] == 0 or bool(x["mentor_id"])) for x in s["class_stations"]), "class over capacity or unmentored")
    elif rule == "mentor_station_refs":
        stations = {x["station_id"]: x for x in s["class_stations"]}
        need(all(x["station_id"] in stations and x["mentor_id"] == stations[x["station_id"]]["mentor_id"] and x["start_min"] < x["end_min"] and x["day_epoch"] <= s["day_epoch"] for x in s["mentor_slots"]), "invalid mentor booking")
    elif rule == "mentor_time_exclusive":
        slots = s["mentor_slots"]
        for i, a in enumerate(slots):
            for b in slots[i+1:]:
                need(not (a["mentor_id"] == b["mentor_id"] and a["day_epoch"] == b["day_epoch"]
                          and a["start_min"] < b["end_min"] and b["start_min"] < a["end_min"]), "mentor double booked")
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
         ["EB-B-%03d" % n for n in range(31, 41)], "wrong civic tranche")
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
        for case in c["invalid_examples"]:
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
        corrupt["receipts"].append("\\u0000")
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
    print("CIVIC DESIGN CONTRACTS PASS: %d valid fixtures, %d invalid fixtures rejected, 10 distinct rule sets; native gameplay NOT tested" % (good, bad))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--data", type=Path, default=DATA)
    args = parser.parse_args()
    self_test(load(args.data))


if __name__ == "__main__":
    main()
