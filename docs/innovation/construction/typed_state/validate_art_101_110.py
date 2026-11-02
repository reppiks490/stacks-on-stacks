#!/usr/bin/env python3
"""Strict B101-B110 design fixture validation; not playable Godot proof."""
import copy
import json
import random
from pathlib import Path

DATA = Path(__file__).with_name("art_101_110.json")
EXPECTED = [f"EB-B-{n:03d}" for n in range(101, 111)]


class InvalidState(Exception):
    pass


def require(ok, reason):
    if not ok:
        raise InvalidState(reason)


def unique(items, reason):
    require(len(items) == len(set(items)), reason)


def typed(value, spec):
    kind = spec["type"]
    if kind == "object":
        require(type(value) is dict and set(value) == set(spec["required"]), "object_fields")
        for name, child in spec["properties"].items():
            typed(value[name], child)
    elif kind == "array":
        require(type(value) is list and len(value) <= spec["max_items"], "array_type")
        for item in value:
            typed(item, spec["items"])
        if spec.get("unique_items"):
            unique([json.dumps(x, sort_keys=True) for x in value], "array_duplicate")
        if spec.get("unique_by"):
            unique([x[spec["unique_by"]] for x in value], "id_duplicate")
    elif kind == "string":
        require(type(value) is str and spec["min_length"] <= len(value) <= spec["max_length"], "string_type")
    elif kind == "integer":
        require(type(value) is int and spec["min"] <= value <= spec["max"], "integer_type")
    elif kind == "boolean":
        require(type(value) is bool, "boolean_type")
    else:
        raise InvalidState("unknown_type")


def domain(n, s):
    if n == 101:
        nodes, v = s["trellis_nodes"], s["vine_age"]
        require(bool(nodes) and all(x["attached"] and 1 <= x["sun_hours"] <= 12 for x in nodes), "trellis_sun")
        unique([x["window_id"] for x in nodes], "trellis_window")
        require(v["days"] <= s["day_epoch"] and
                s["day_epoch"] - v["days"] <= v["last_pruned_epoch"] <= s["day_epoch"] and
                v["stage"] == max(0, min(5, v["days"] * min(x["sun_hours"] for x in nodes) // 42) -
                (1 if s["day_epoch"] - v["last_pruned_epoch"] <= 3 else 0)), "trellis_age")
    elif n == 102:
        m, p = s["metal_surface"], s["patina_age"]
        require(m["moisture_percent"] <= 100 and m["sealant_percent"] <= 100
                and m["finish"] in ("raw", "sealed", "brushed"), "patina_material")
        require(p["days"] <= s["day_epoch"] and p["level"] == min(
                100, p["days"] * m["moisture_percent"] * (100 - m["sealant_percent"]) // 10000),
                "patina_level")
    elif n == 103:
        a, c = s["awning_angle"], s["cloth_integrity"]
        require(a["degrees"] <= 180 and a["wind_kph"] <= 120 and
                2 <= a["anchor_count"] <= 16, "awning_support")
        require(c["wear_epoch"] <= s["day_epoch"] and
                c["shade_percent"] == max(0, 100 - 2 * abs(a["degrees"] - 45)) and
                c["current_percent"] == max(0, 100 - a["wind_kph"] * a["degrees"] // 60),
                "awning_wear")
    elif n == 104:
        cuts, light = s["screen_cutouts"], s["light_source_id"]
        require(bool(cuts) and all(0 < x["area_cm2"] <= 100 for x in cuts)
                and sum(x["area_cm2"] for x in cuts) <= 100, "cutout_area")
        unique([(x["x_mm"], x["y_mm"]) for x in cuts], "cutout_overlap")
        require(not light["lit"] or light["fuel_units"] > 0, "lantern_fuel")
        require(light["projected_area_cm2"] == (2 * sum(x["area_cm2"] for x in cuts)
                if light["lit"] else 0), "lantern_projection")
    elif n == 105:
        seg, a = s["surface_material"]["segments"], s["sound_profile"]
        require(bool(seg) and all(x["material"] in ("timber", "stone", "clay")
                and x["length_cm"] > 0 for x in seg), "sound_surface")
        require(a["gait"] in ("walk", "run", "sneak") and
                a["clip_id"] == seg[0]["material"] + "_" + a["gait"] and
                a["events_per_step"] == 1, "sound_bounded")
    elif n == 106:
        p, f = s["pool_capacity"], s["fountain_flow"]
        require(p["liters"] > 0 and p["water_liters"] <= p["liters"]
                and p["rain_receipt_id"].startswith("rain-"), "pool_capacity")
        require(f["recirculated"] and f["source_id"] == p["pool_id"]
                and f["liters_per_tick"] <= p["water_liters"]
                and f["water_debit_liters"] == 0, "fountain_conservation")
    elif n == 107:
        p, f = s["pane_temperature"], s["frost_mask"]
        require(p["celsius_x10"] < 0 and p["heat_units"] < 5 and
                50 <= p["humidity_percent"] <= 100, "frost_weather")
        require(len(f["cells"]) <= 10 and all(x <= 99 for x in f["cells"])
                and f["coverage_percent"] == 10 * len(f["cells"])
                and f["thaw_epoch"] >= s["day_epoch"], "frost_coverage")
    elif n == 108:
        b, a = s["rotor_blades"], s["angular_speed"]
        require(2 <= b["count"] <= 8 and b["balanced"] and b["wear_percent"] <= 100,
                "rotor_blades")
        require(a["wind_kph"] <= 120 and 1 <= a["limit_rpm"] <= 120 and
                a["rpm"] == min(a["limit_rpm"],
                a["wind_kph"] * b["count"] * (100 - b["wear_percent"]) // 100),
                "rotor_rpm")
    elif n == 109:
        a, w = s["aperture_azimuth"], s["star_window"]
        require(a["degrees"] < 360 and a["roof_clearance"] and
                a["occlusion_percent"] < 50, "roof_block")
        require(w["start_epoch"] <= w["end_epoch"] <= w["start_epoch"] + 14
                and w["visible"] == (w["start_epoch"] <= s["day_epoch"] <= w["end_epoch"]),
                "star_visibility")
    elif n == 110:
        p, f = s["facade_palette"], s["finish_revision"]
        require(p["base"] in ("ochre", "slate", "sage") and
                p["trim"] in ("cream", "umber", "ochre") and
                p["base"] != p["trim"] and bool(p["motif_ids"]), "facade_colors")
        require(f["revision"] == s["revision"] == f["source_revision"] and
                f["structural_bonus"] == 0 and f["weatherproof_bonus"] == 0,
                "facade_cheat")
    else:
        raise InvalidState("unknown_feature")


def validate(record, state):
    typed(state, record["save_contract"]["schema"])
    domain(int(record["id"][-3:]), state)


def changed(state, path, value):
    out = copy.deepcopy(state)
    node = out
    for part in path[:-1]:
        node = node[part]
    node[path[-1]] = value
    return out


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
        return rng.choice([0, None, "false"])
    if type(value) is int:
        return rng.choice([True, None, "invalid"])
    if type(value) is str:
        return rng.choice([42, None, False])
    return None


def expect_invalid(record, state, label):
    try:
        validate(record, state)
    except (InvalidState, TypeError, ValueError, KeyError, OverflowError):
        return
    raise AssertionError(f"{record['id']} accepted invalid {label}")


def run():
    payload = json.loads(DATA.read_text(encoding="utf-8"))
    records = payload["state_contracts"]
    require([r["id"] for r in records] == EXPECTED, "roster")
    require(payload["source_blob"] == "d94bee3a56fa18dc6fdb15ed6b3a1a6fe070b79b", "catalog_blob")
    require(payload["phaseC"].startswith("CLOSED"), "phase_gate")
    unique([r["save_contract"]["namespace"] for r in records], "namespace")
    rng = random.Random(20261102)
    valid = hostile = common = fuzz = roundtrips = epochs = 0
    for record in records:
        n = int(record["id"][-3:])
        require(record["status"] == "typed_design_only_not_playable", "false_status")
        require(record["save_contract"]["namespace"] == f"construction.eb_b_{n:03d}", "namespace")
        require(len(record["valid_fixtures"]) == 2 and len(record["hostile_mutations"]) >= 4,
                "fixtures")
        require(set(record["source_field_mapping"]) ==
                set(record["save_contract"]["schema"]["properties"]) -
                {"site_id", "revision", "day_epoch", "receipts"}, "source_fields")
        require(set(record["controls"]) >= {"mouse_keyboard", "gamepad", "touch"}, "controls")
        require(bool(record["original_asset_plan"]) and bool(record["acceptance"]) and
                bool(record["dependencies"]), "feature_contract")
        first, second = record["valid_fixtures"]
        require(first["day_epoch"] == 56 and second["day_epoch"] == 112, "year_rollover")
        epochs += 1
        for state in record["valid_fixtures"]:
            validate(record, state)
            valid += 1
            encoded = json.dumps(state, sort_keys=True, separators=(",", ":"), allow_nan=False)
            decoded = json.loads(encoded)
            validate(record, decoded)
            require(decoded == state, "roundtrip")
            roundtrips += 1
            for m in record["hostile_mutations"]:
                expect_invalid(record, changed(state, m["path"], m["value"]), m["name"])
                hostile += 1
            cases = [
                ("missing_site", {k: copy.deepcopy(v) for k, v in state.items() if k != "site_id"}),
                ("unknown_field", dict(state, injected_field=1)),
                ("duplicate_receipt", changed(state, ["receipts"], state["receipts"] * 2)),
                ("negative_revision", changed(state, ["revision"], -1)),
                ("boolean_epoch", changed(state, ["day_epoch"], True)),
                ("nan_revision", changed(state, ["revision"], float("nan"))),
                ("malformed_receipts", changed(state, ["receipts"], {"bad": 1})),
                ("invalid_nested", changed(state, [list(record["source_field_mapping"])[0]], None)),
            ]
            for label, bad in cases:
                expect_invalid(record, bad, label)
                common += 1
            options = list(leaves(state))
            for _ in range(16):
                path, value = rng.choice(options)
                expect_invalid(record, changed(state, path, wrong_type(value, rng)),
                               "seeded_type_fuzz")
                fuzz += 1
    print(f"ART_CONTRACTS={len(records)} VALID={valid} HOSTILE_REJECTED={hostile} "
          f"COMMON_REJECTED={common} SEEDED_FUZZ_REJECTED={fuzz} "
          f"ROUNDTRIPS={roundtrips} TWO_YEAR_EPOCH_CHECKS={epochs}")
    print("DESIGN_ONLY=TRUE NATIVE_GODOT_GAMEPLAY_PROOF=FALSE")
    return 0


if __name__ == "__main__":
    raise SystemExit(run())
