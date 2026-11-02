#!/usr/bin/env python3
"""Offline, dependency-free design-state validator. NOT a Godot gameplay test."""
import argparse
import copy
import json
import math
from pathlib import Path

DATA = Path(__file__).with_name("structural_011_020.json")
MAX_EPOCH = 9007199254740991


class ContractError(ValueError):
    pass


def require(ok, message):
    if not ok:
        raise ContractError(message)


def load_data(path=DATA):
    def reject_nonfinite(value):
        raise ContractError("nonfinite JSON token: " + value)
    return json.loads(Path(path).read_text(encoding="utf-8"), parse_constant=reject_nonfinite)


def validate_value(spec, value, path):
    kind = spec["type"]
    if kind == "integer":
        require(type(value) is int, path + ": expected integer")
        require(spec["min"] <= value <= spec["max"], path + ": integer bounds")
    elif kind == "boolean":
        require(type(value) is bool, path + ": expected boolean")
    elif kind == "string":
        require(type(value) is str, path + ": expected string")
        require(spec.get("min_length", 0) <= len(value) <= spec["max_length"], path + ": string length")
        require(not any(ord(c) < 32 for c in value), path + ": control character")
    elif kind == "enum":
        require(type(value) is str and value in spec["values"], path + ": invalid enum")
    elif kind == "list":
        require(type(value) is list and len(value) <= spec["max_items"], path + ": invalid list")
        for j, item in enumerate(value):
            validate_value(spec["items"], item, path + "[" + str(j) + "]")
        if "unique_by" in spec:
            key = spec["unique_by"]
            vals = [item[key] for item in value]
            require(len(vals) == len(set(vals)), path + ": duplicate " + key)
    elif kind == "object":
        require(type(value) is dict, path + ": expected object")
        fields = spec["fields"]
        require(set(value) == set(fields), path + ": missing or extra object fields")
        for key, child in fields.items():
            validate_value(child, value[key], path + "." + key)
    else:
        raise ContractError(path + ": unknown field type " + str(kind))


def orient(a, b, c):
    return (b["x_cm"] - a["x_cm"]) * (c["z_cm"] - a["z_cm"]) - (b["z_cm"] - a["z_cm"]) * (c["x_cm"] - a["x_cm"])


def on_segment(a, b, p):
    return (min(a["x_cm"], b["x_cm"]) <= p["x_cm"] <= max(a["x_cm"], b["x_cm"])
            and min(a["z_cm"], b["z_cm"]) <= p["z_cm"] <= max(a["z_cm"], b["z_cm"]))


def intersects(a, b, c, d):
    x, y, z, w = orient(a, b, c), orient(a, b, d), orient(c, d, a), orient(c, d, b)
    if (x > 0 > y or x < 0 < y) and (z > 0 > w or z < 0 < w):
        return True
    return ((x == 0 and on_segment(a, b, c)) or (y == 0 and on_segment(a, b, d))
            or (z == 0 and on_segment(c, d, a)) or (w == 0 and on_segment(c, d, b)))


def validate_rule(code, st):
    if code == "simple_polygon_area":
        pts = st["parcel_polygon"]
        if pts:
            require(3 <= len(pts), "polygon needs three vertices")
            area2 = abs(sum(p["x_cm"] * pts[(j + 1) % len(pts)]["z_cm"] -
                            pts[(j + 1) % len(pts)]["x_cm"] * p["z_cm"] for j, p in enumerate(pts)))
            require(area2 >= 80000, "polygon needs >=4 square metres")
            n = len(pts)
            for j in range(n):
                for k in range(j + 1, n):
                    if k in (j, (j + 1) % n) or (j == 0 and k == n - 1):
                        continue
                    require(not intersects(pts[j], pts[(j + 1) % n], pts[k], pts[(k + 1) % n]), "self-intersecting polygon")
    elif code == "polygon_access_consent":
        require(not st["parcel_polygon"] or bool(st["access_receipts"]), "missing access consent")
        require(not st["access_receipts"] or bool(st["parcel_polygon"]), "orphan access consent")
    elif code == "consent_epoch_bound":
        require(all(r["epoch"] <= st["day_epoch"] for r in st["access_receipts"]), "future consent")
    elif code == "soil_required_for_dampers":
        require(not st["damper_graph"] or st["soil_class"] != "unknown", "soil class required")
    elif code == "grounded_damper_required":
        require(not st["damper_graph"] or any(r["grounded"] for r in st["damper_graph"]), "ungrounded damper graph")
    elif code == "offcut_lte_input":
        require(st["offcut_mass"] <= st["input_mass_g"], "offcuts exceed input mass")
    elif code == "spline_spacing":
        pts = st["control_points"]
        require(not pts or len(pts) >= 2, "incomplete spline")
        for p, q in zip(pts, pts[1:]):
            require((p["x_cm"] - q["x_cm"]) ** 2 + (p["z_cm"] - q["z_cm"]) ** 2 >= 900, "coincident spline handles")
    elif code == "panel_segment_bound":
        require(all(p["segment_index"] < len(st["control_points"]) - 1 for p in st["panels"]), "panel segment missing")
    elif code == "jamb_width":
        require(all(p["opening_width_cm"] <= p["width_cm"] - 20 for p in st["panels"]), "insufficient jamb")
    elif code == "cure_after_laid":
        require(not st["course_graph"] or st["cure_epoch"] >= max(c["laid_epoch"] for c in st["course_graph"]) + 1, "mortar not cured")
    elif code == "laid_not_future":
        require(all(c["laid_epoch"] <= st["day_epoch"] for c in st["course_graph"]), "future masonry")
    elif code == "roof_face_ref":
        refs = {r["face_id"] for r in st["roof_faces"]}
        require(all(l["face_id"] in refs for l in st["load_map"]), "orphan roof load")
    elif code == "snow_lte_rating":
        refs = {r["face_id"]: r["support_rating_kg"] for r in st["roof_faces"]}
        require(all(l["snow_kg"] <= refs.get(l["face_id"], -1) for l in st["load_map"]), "roof overloaded")
    elif code == "riser_max_22":
        require(all(r["rise_cm"] <= 22 * r["tread_count"] for r in st["stair_runs"]), "excessive stair rise")
    elif code == "headroom_min_190":
        require(all(r["headroom_cm"] >= 190 for r in st["stair_runs"]), "headroom blocked")
    elif code == "clearance_min_90":
        require(not st["stair_runs"] or st["clearance"] >= 90, "stairs block passage")
    elif code == "lift_track_ascending":
        track = st["lift_track"]
        require(all(b["floor_index"] > a["floor_index"] and b["elevation_cm"] > a["elevation_cm"]
                    for a, b in zip(track, track[1:])), "nonascending lift track")
    elif code == "cargo_two_floors":
        require(not st["cargo_manifest"] or len(st["lift_track"]) >= 2, "cargo without lift endpoints")
    elif code == "cargo_capacity":
        require(sum(c["mass_kg"] * c["quantity"] for c in st["cargo_manifest"]) <= st["rated_capacity_kg"], "cargo overload")
    elif code == "leak_edge_ref":
        refs = {e["edge_id"] for e in st["thermal_edges"]}
        require(all(e["edge_id"] in refs for e in st["leak_map"]), "orphan thermal leak")
    elif code == "vent_nonzero_leak":
        leaks = {e["edge_id"]: e["heat_loss_mw"] for e in st["leak_map"]}
        require(all(leaks.get(e["edge_id"], 0) > 0 for e in st["thermal_edges"] if e["vent_open"]), "open vent without heat loss")
    elif code == "brace_distinct_endpoints":
        require(all(b["from_anchor"] != b["to_anchor"] for b in st["brace_graph"]), "self-loop brace")
    elif code == "grounded_brace":
        require(not st["brace_graph"] or any(b["grounded"] for b in st["brace_graph"]), "unanchored brace network")
    elif code == "wind_capacity":
        capacity = sum(b["capacity_kg"] for b in st["brace_graph"] if b["grounded"])
        require(st["wind_case"]["expected_load_kg"] <= capacity, "wind exceeds grounded capacity")
    else:
        raise ContractError("unimplemented rule " + code)


def validate_state(contract, st):
    fields = contract["fields"]
    require(type(st) is dict and set(st) == set(fields), contract["id"] + ": unknown/missing state keys")
    for key, spec in fields.items():
        validate_value(spec, st[key], contract["id"] + "." + key)
    require(len(st["receipts"]) == len(set(st["receipts"])), "duplicate settlement receipt")
    require(not st["receipts"] or (bool(st["site_id"]) and st["day_epoch"] >= 1 and st["revision"] >= 1),
            "committed receipt without site/epoch/revision")
    for rule in contract["rules"]:
        validate_rule(rule, st)
    return True


def check_catalog(data):
    contracts = data["state_contracts"]
    require(len(contracts) == 10, "expected exactly ten contracts")
    require(data["phaseC"].startswith("closed"), "Phase C must remain closed")
    require(data["source"]["blob_sha"] == "d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b", "unpinned source")
    ids = [c["id"] for c in contracts]
    require(ids == ["EB-B-%03d" % i for i in range(11, 21)], "wrong ID/order")
    for c in contracts:
        fields = c["fields"]
        require(set(c["source_fields"]).issubset(fields), c["id"] + ": source field lost")
        require(set(c["additions"]) == set(fields) - set(c["source_fields"]), c["id"] + ": undeclared addition")
        require(c["state_version"] == 1 and c["save_namespace"].startswith("construction."), "bad state namespace")
        require(len(c["rules"]) >= 1 and len(c["invalid_examples"]) >= 2, "missing adversarial coverage")
        defaults = {k: copy.deepcopy(v["default"]) for k, v in fields.items()}
        validate_state(c, defaults)
        validate_state(c, c["valid_example"])
    return contracts


def must_reject(contract, state, reason):
    try:
        validate_state(contract, state)
    except (ContractError, KeyError, TypeError, ValueError):
        return
    raise AssertionError(contract["id"] + ": invalid case accepted: " + reason)


def self_test(data):
    contracts = check_catalog(data)
    count = 0
    for c in contracts:
        valid = c["valid_example"]
        for bad in c["invalid_examples"]:
            must_reject(c, bad["state"], bad["reason"])
            count += 1
        for key in c["fields"]:
            invalid = copy.deepcopy(valid)
            invalid[key] = None
            must_reject(c, invalid, "null " + key)
            count += 1
        invalid = copy.deepcopy(valid)
        invalid["unexpected_key"] = 1
        must_reject(c, invalid, "unknown key")
        count += 1
        invalid = copy.deepcopy(valid)
        del invalid["revision"]
        must_reject(c, invalid, "missing revision")
        count += 1
        for key, value in [("receipts", ["cmdA", "cmdA"]), ("site_id", ""), ("day_epoch", -1), ("revision", 0)]:
            invalid = copy.deepcopy(valid)
            invalid[key] = value
            must_reject(c, invalid, "receipt authority " + key)
            count += 1
        for key, spec in c["fields"].items():
            if spec["type"] == "list" and "unique_by" in spec and valid[key]:
                invalid = copy.deepcopy(valid)
                invalid[key] = [copy.deepcopy(valid[key][0]), copy.deepcopy(valid[key][0])]
                must_reject(c, invalid, "duplicate nested " + key)
                count += 1
    # Reject hostile JSON constants before validation.
    for token in ("NaN", "Infinity", "-Infinity"):
        try:
            json.loads('{"x":' + token + '}', parse_constant=lambda x: (_ for _ in ()).throw(ContractError(x)))
        except ContractError:
            count += 1
        else:
            raise AssertionError("nonfinite JSON accepted")
    return len(contracts), sum(len(c["fields"]) for c in contracts), sum(len(c["rules"]) for c in contracts), count


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    data = load_data()
    if args.self_test:
        n, fields, rules, bad = self_test(data)
        print("PASS: %d contracts, %d typed fields, %d rules, %d invalid cases rejected; 0 harness failures" %
              (n, fields, rules, bad))
    else:
        contracts = check_catalog(data)
        print("PASS: %d typed structural design contracts; NOT Godot gameplay" % len(contracts))


if __name__ == "__main__":
    main()
