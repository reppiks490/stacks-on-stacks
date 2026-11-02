#!/usr/bin/env python3
"""Design-only typed-state and adversarial validator for EVERBLOOM B071-B080.

No gameplay implementation, Godot engine execution, inventory writes or save migration.
Standard-library-only, deterministic and deliberately fail-closed.
"""
from __future__ import annotations

import copy
import json
import math
import random
from collections import defaultdict, deque
from pathlib import Path

FILE = Path(__file__).with_name("household_071_080.json")
EXPECTED = [f"EB-B-{n:03d}" for n in range(71, 81)]


class InvalidState(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise InvalidState(reason)


def unique(values, reason: str) -> None:
    require(len(values) == len(set(values)), reason)


def typed(value, schema: dict, path: str = "state") -> None:
    kind = schema["type"]
    if kind == "object":
        require(type(value) is dict, f"{path}:object")
        props = schema["properties"]
        require(set(schema["required"]) <= set(value), f"{path}:missing_field")
        if schema.get("additional_properties") is False:
            require(set(value) <= set(props), f"{path}:unknown_field")
        for name, val in value.items():
            typed(val, props[name], f"{path}.{name}")
    elif kind == "array":
        require(type(value) is list, f"{path}:array")
        require(len(value) <= schema["max_items"], f"{path}:array_bound")
        for i, item in enumerate(value):
            typed(item, schema["items"], f"{path}[{i}]")
        if schema.get("unique_items"):
            unique([json.dumps(x, sort_keys=True, allow_nan=False) for x in value],
                   f"{path}:duplicate_items")
        if schema.get("unique_by"):
            key = schema["unique_by"]
            unique([x[key] for x in value], f"{path}:duplicate_{key}")
    elif kind == "integer":
        require(type(value) is int, f"{path}:integer_not_bool_or_float")
        require(schema["min"] <= value <= schema["max"], f"{path}:integer_bound")
    elif kind == "boolean":
        require(type(value) is bool, f"{path}:boolean")
    elif kind == "string":
        require(type(value) is str, f"{path}:string")
        require(schema["min_length"] <= len(value) <= schema["max_length"],
                f"{path}:string_bound")
    else:
        raise InvalidState(f"{path}:unsupported_type")


def connected(start, target, adjacency):
    queue, visited = deque([start]), {start}
    while queue:
        node = queue.popleft()
        if node == target:
            return True
        for neighbor in adjacency[node]:
            if neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return False


def household_rules(fid: str, s: dict) -> None:
    num = int(fid[-3:])
    if num == 71:
        rooms = {r["room_id"]: r for r in s["rooms"]}
        consents = {c["id"]: c for c in s["consents"]}
        for r in rooms.values():
            require(1 <= r["beds"] <= 12, "occupancy_capacity")
        bookings = s["bookings"]
        for b in bookings:
            require(b["room_id"] in rooms, "booking_room")
            room = rooms[b["room_id"]]
            require(room["exits_clear"] and room["privacy"], "safe_egress_privacy")
            require(b["arrival_epoch"] < b["departure_epoch"], "booking_window")
            c = consents.get(b["consent_id"])
            require(c is not None and c["active"] and c["guest_id"] == b["guest_id"],
                    "guest_consent")
        for b in bookings:
            overlapping = [x for x in bookings
                           if x["room_id"] == b["room_id"]
                           and x["arrival_epoch"] < b["departure_epoch"]
                           and b["arrival_epoch"] < x["departure_epoch"]]
            require(len(overlapping) <= rooms[b["room_id"]]["beds"], "booking_capacity")
            same_guest = [x for x in bookings
                          if x["guest_id"] == b["guest_id"]
                          and x["arrival_epoch"] < b["departure_epoch"]
                          and b["arrival_epoch"] < x["departure_epoch"]]
            require(len(same_guest) == 1, "guest_double_booking")
    elif num == 72:
        zones = {z["id"]: z for z in s["zones"]}
        require(any(z["amenity"] and z["open"] for z in zones.values()), "amenity_available")
        for pet in s["companions"]:
            require(pet["zone_id"] in zones and zones[pet["zone_id"]]["open"],
                    "companion_zone")
            adj = defaultdict(list)
            for link in s["links"]:
                require(link["a"] in zones and link["b"] in zones, "zone_reference")
                if (link["gate_open"] and link["clearance_cm"] >= pet["min_clearance_cm"]
                        and zones[link["a"]]["open"] and zones[link["b"]]["open"]):
                    adj[link["a"]].append(link["b"])
                    adj[link["b"]].append(link["a"])
            require(any(connected(pet["zone_id"], z["id"], adj)
                        for z in zones.values() if z["amenity"] and z["open"]),
                    "amenity_reach")
    elif num == 73:
        rooms = {r["id"]: r for r in s["rooms"]}
        deps = {d["id"]: d for d in s["dependents"]}
        stages = ["infant", "toddler", "child", "teen"]
        for room in rooms.values():
            require(room["capacity"] > 0 and room["safe"], "nursery_capacity_safety")
            require(sum(d["room_id"] == room["id"] for d in deps.values())
                    <= room["capacity"], "nursery_occupancy")
        for d in deps.values():
            require(d["room_id"] in rooms and d["consent"] and d["guardian_id"],
                    "guardian_consent")
            require(d["stage"] in stages, "dependent_stage")
        for t in s["transitions"]:
            require(t["dependent_id"] in deps and t["approved"], "transition_approval")
            d = deps[t["dependent_id"]]
            require(t["from_stage"] == d["stage"], "transition_from")
            require(t["to_stage"] in stages
                    and stages.index(t["to_stage"]) == stages.index(d["stage"]) + 1,
                    "stage_progression")
            require(t["day_epoch"] >= s["day_epoch"], "transition_epoch")
            require(any(p["room_id"] == d["room_id"] and p["installed"]
                        and t["from_stage"] in p["compatible_stages"]
                        and t["to_stage"] in p["compatible_stages"]
                        for p in s["convertible_parts"]), "conversion_component")
        for part in s["convertible_parts"]:
            require(part["room_id"] in rooms, "conversion_room_reference")
            require(all(stage in stages for stage in part["compatible_stages"]),
                    "conversion_stage_reference")
    elif num == 74:
        levels = {v["id"]: v["height_cm"] for v in s["levels"]}
        require("ground" in levels and levels["ground"] == 0, "ground_level")
        adj = defaultdict(list)
        for edge in s["connectors"]:
            a, b = edge["from"], edge["to"]
            require(a in levels and b in levels and a != b, "connector_reference")
            require(edge["rise_cm"] == abs(levels[a] - levels[b]), "rise_consistency")
            require(edge["width_cm"] >= 90, "access_width")
            require(edge["kind"] in ("ramp", "lift"), "connector_kind")
            if edge["kind"] == "ramp":
                require(edge["run_cm"] > 0 and edge["rise_cm"] * 1000
                        <= edge["run_cm"] * 83, "ramp_slope")
            if edge["open"]:
                adj[a].append(b)
                adj[b].append(a)
        for target in s["essentials"]:
            require(target in levels and connected("ground", target, adj),
                    "essential_reach")
        for profile in s["mobility_profiles"]:
            start = profile["start_level"]
            require(start in levels, "mobility_start")
            filtered = defaultdict(list)
            for edge in s["connectors"]:
                if not edge["open"] or edge["width_cm"] < profile["min_width_cm"]:
                    continue
                if (edge["kind"] == "ramp" and
                        edge["rise_cm"] * 1000 >
                        edge["run_cm"] * profile["max_slope_permille"]):
                    continue
                filtered[edge["from"]].append(edge["to"])
                filtered[edge["to"]].append(edge["from"])
            require(all(target in levels and connected(start, target, filtered)
                        for target in profile["required_levels"]), "mobility_slope_reach")
    elif num == 75:
        residents = {r["id"]: r for r in s["residents"]}
        spaces = {x["id"]: x for x in s["spaces"]}
        pairs = []
        for right in s["rights"]:
            rid, sid = right["resident_id"], right["space_id"]
            require(rid in residents and residents[rid]["consent"], "resident_consent")
            require(sid in spaces, "space_reference")
            require(right["approved"] and not right["revoked"], "rights_approval_revocation")
            pairs.append((rid, sid))
        unique(pairs, "duplicate_right")
        approved_pairs = set(pairs)
        for cabinet in s["private_inventory"]:
            require(cabinet["space_id"] in spaces, "private_inventory_space")
            require(all((rid, cabinet["space_id"]) in approved_pairs
                        for rid in cabinet["allowed_residents"]),
                    "private_inventory_right")
    elif num == 76:
        hours = s["hours"]
        require(0 <= hours["open_min"] < hours["close_min"] <= 1440, "shop_hours")
        lots = {x["id"]: x for x in s["stock_lots"]}
        totals = defaultdict(int)
        order_receipts = []
        for order in s["orders"]:
            require(order["lot_id"] in lots and order["quantity"] > 0, "order_lot_qty")
            if order["fulfilled"]:
                require(bool(order["receipt"]), "sale_receipt")
                totals[order["lot_id"]] += order["quantity"]
                order_receipts.append(order["receipt"])
        unique(order_receipts, "duplicate_sale_receipt")
        for lot in lots.values():
            require(lot["received"] == lot["sold"] + lot["remaining"],
                    "stock_conservation")
            require(lot["received"] <= lot["capacity"], "stock_capacity")
            require(totals[lot["id"]] == lot["sold"], "order_reconciliation")
        zones = {z["id"]: z for z in s["zones"]}
        require(s["shop_zone_id"] in zones and zones[s["shop_zone_id"]]["public"],
                "public_shop_zone")
        adj = defaultdict(list)
        for edge in s["paths"]:
            require(edge["from"] in set(zones) | {"street"} and
                    edge["to"] in set(zones) | {"street"}, "shop_path_reference")
            if edge["open"]:
                adj[edge["from"]].append(edge["to"])
                adj[edge["to"]].append(edge["from"])
        require(connected("street", s["shop_zone_id"], adj), "public_shop_reach")
        for private_id in s["private_zone_ids"]:
            require(private_id in zones and not zones[private_id]["public"],
                    "private_zone_reference")
            require(not connected("street", private_id, adj), "private_zone_leak")
    elif num == 77:
        barriers = {b["id"]: b for b in s["barriers"]}
        for q in s["quiet_hours"]:
            require(0 <= q["start_min"] < q["end_min"] <= 1440, "quiet_window")
        for session in s["sessions"]:
            require(0 <= session["start_min"] < session["end_min"] <= 1440,
                    "session_window")
            barrier = barriers.get(session["room_id"])
            require(barrier is not None and barrier["installed"], "barrier_installed")
            require(0 <= barrier["attenuation_pct"] <= 100, "attenuation_bound")
            overlapping = any(session["start_min"] < q["end_min"]
                              and q["start_min"] < session["end_min"]
                              for q in s["quiet_hours"])
            if overlapping and not session["consent"]:
                require(session["raw_noise"] * (100 - barrier["attenuation_pct"])
                        <= 3500, "quiet_noise")
    elif num == 78:
        shades = {x["id"]: x for x in s["shades"]}
        for shade in shades.values():
            require(0 <= shade["angle_deg"] <= 90, "shade_angle")
            require(0 <= shade["vent_pct"] <= 100
                    and 0 <= shade["solar_gain_pct"] <= 100, "climate_pct")
        for climate in s["climates"]:
            shade = shades.get(climate["id"])
            require(shade is not None, "shade_reference")
            delta = shade["solar_gain_pct"] // 2 - shade["vent_pct"] // 4
            require(climate["delta_c10"] == delta, "climate_delta")
            require(climate["reported_c10"] == climate["baseline_c10"] + delta,
                    "climate_reconcile")
            require(climate["water_granted_l"] <= climate["water_requested_l"],
                    "water_authority")
    elif num == 79:
        mounts = {m["id"]: m for m in s["mounts"]}
        claims = []
        for mount in mounts.values():
            require(mount["load_kg"] <= mount["capacity_kg"], "mount_load")
            require(mount["vibration_milli"] <= 50, "mount_vibration")
            require(mount["clearance_deg"] >= 45, "mount_clearance")
        for obs in s["observations"]:
            require(obs["mount_id"] in mounts, "mount_reference")
            require(obs["visibility_pct"] <= 100 and obs["required_pct"] <= 100,
                    "visibility_bound")
            require(obs["day_epoch"] >= s["day_epoch"], "observation_epoch")
            if obs["claimed"]:
                require(obs["visibility_pct"] >= obs["required_pct"], "sky_visibility")
                claims.append((obs["mount_id"], obs["day_epoch"]))
        unique(claims, "duplicate_observation_claim")
    elif num == 80:
        chambers = {c["id"]: c for c in s["chambers"]}
        adj = defaultdict(list)
        for tunnel in s["tunnels"]:
            require(tunnel["from"] in set(s["entries"]) | set(chambers)
                    and tunnel["to"] in set(s["entries"]) | set(chambers),
                    "tunnel_reference")
            if tunnel["open"] and tunnel["clearance_cm"] >= 90:
                adj[tunnel["from"]].append(tunnel["to"])
                adj[tunnel["to"]].append(tunnel["from"])
        require(bool(s["entries"]), "cellar_entry")
        for chamber in chambers.values():
            require(chamber["food_l"] <= chamber["volume_l"], "food_capacity")
            require(chamber["support_kg"] >= chamber["roof_load_kg"], "roof_support")
            require(chamber["groundwater_depth_cm"] >= chamber["floor_depth_cm"] + 50,
                    "groundwater_clearance")
            require(chamber["barrier_pct"] >= 60, "moisture_barrier")
            require(any(connected(entry, chamber["id"], adj) for entry in s["entries"]),
                    "cellar_egress")
    else:
        raise InvalidState("unknown_feature")


def validate(spec: dict, state: dict) -> None:
    typed(state, spec["save_contract"]["schema"])
    household_rules(spec["id"], state)


def mutate(state: dict, path: list, value=None, delete=False) -> dict:
    result = copy.deepcopy(state)
    node = result
    for part in path[:-1]:
        node = node[part]
    if delete:
        del node[path[-1]]
    else:
        node[path[-1]] = value
    return result


def must_reject(spec: dict, state: dict, label: str) -> None:
    try:
        validate(spec, state)
    except InvalidState:
        return
    raise AssertionError(f"{spec['id']} unexpectedly accepted {label}")


def run() -> None:
    data = json.loads(FILE.read_text(encoding="utf-8"))
    require(data["schema_version"] == 1 and data["engine"] == "Godot 4.x",
            "metadata")
    require("CLOSED" in data["phaseC"], "phase_gate")
    specs = data["state_contracts"]
    require([x["id"] for x in specs] == EXPECTED, "id_coverage_order")
    unique([x["title"].casefold() for x in specs], "duplicate_titles")
    valid_count = targeted = hostile = fuzzed = roundtrips = 0
    rng = random.Random(20261102)
    for spec in specs:
        require(spec["status"] == "typed_design_only_not_playable", "status")
        require(spec["save_contract"]["namespace"]
                == "construction.eb_b_" + spec["id"][-3:], "namespace")
        require(len(spec["negative_mutations"]) >= 4, "negative_coverage")
        require(all(spec["controls"].get(k) for k in
                    ("keyboard_mouse", "gamepad", "touch")), "controls")
        require(bool(spec["original_asset_plan"])
                and bool(spec["godot_acceptance"])
                and bool(spec["negative_acceptance"]), "acceptance")
        require(all(k in spec["performance_budget"] for k in
                    ("desktop", "mobile")), "budgets")
        for state in spec["valid_examples"]:
            validate(spec, state)
            valid_count += 1
            packed = json.dumps(state, sort_keys=True, separators=(",", ":"),
                                allow_nan=False)
            loaded = json.loads(packed)
            require(loaded == state and
                    json.dumps(loaded, sort_keys=True, separators=(",", ":"),
                               allow_nan=False) == packed, "json_roundtrip")
            validate(spec, loaded)
            roundtrips += 1
        base = spec["valid_examples"][0]
        for negative in spec["negative_mutations"]:
            must_reject(spec, mutate(base, negative["path"], negative["value"]),
                        negative["rule"])
            targeted += 1
        other_key = next(k for k in base if k not in
                         ("site_id", "revision", "day_epoch", "receipts"))
        invalids = [
            ("empty_site", mutate(base, ["site_id"], "")),
            ("negative_revision", mutate(base, ["revision"], -1)),
            ("negative_epoch", mutate(base, ["day_epoch"], -1)),
            ("epoch_overflow", mutate(base, ["day_epoch"], 9007199254740992)),
            ("duplicate_receipts", mutate(base, ["receipts"], ["dup", "dup"])),
            ("wrong_receipt_type", mutate(base, ["receipts"], [42])),
            ("unknown_top_field", mutate(base, ["rogue"], True)),
            ("missing_revision", mutate(base, ["revision"], delete=True)),
            ("nan_revision", mutate(base, ["revision"], float("nan"))),
            ("long_receipt", mutate(base, ["receipts"], ["X" * 97])),
            ("wrong_nested_type", mutate(base, [other_key], "bad")),
        ]
        nested = base[other_key]
        if isinstance(nested, list) and nested:
            invalids.append(("duplicate_nested_entry",
                             mutate(base, [other_key], nested + [copy.deepcopy(nested[0])])))
        for label, candidate in invalids:
            must_reject(spec, candidate, label)
            hostile += 1
        for _ in range(32):
            key = rng.choice(list(base))
            must_reject(spec, mutate(base, [key], None), "seeded_fuzz_null")
            fuzzed += 1
    print(f"B071-B080 design contracts: {len(specs)}")
    print(f"Valid fixtures: {valid_count}; canonical JSON roundtrips: {roundtrips}")
    print(f"Targeted domain negatives rejected: {targeted}")
    print(f"Common hostile mutations rejected: {hostile}")
    print(f"Deterministic seeded null-fuzz rejected: {fuzzed}")
    print(f"Total negative states rejected: {targeted + hostile + fuzzed}")
    print("PASS — design-state validation only; no native gameplay claim")


if __name__ == "__main__":
    run()
