#!/usr/bin/env python3
"""B081-B090 design-only typed-state and adversarial verification.

This is NOT a Godot gameplay test or an inventory authority implementation.
Standard-library-only; deterministic and fail-closed.
"""
from __future__ import annotations

import copy
import json
import random
from collections import defaultdict, deque
from pathlib import Path

DATA = Path(__file__).with_name("community_081_090.json")
EXPECTED = [f"EB-B-{i:03d}" for i in range(81, 91)]
SOURCE_FIELDS = {
    81: ("walkway_elevation", "evac_routes"),
    82: ("heating_fuel", "guest_receipts"),
    83: ("pavilion_modules", "festival_slot"),
    84: ("dedication_ids", "consent_receipts"),
    85: ("beacon_height", "warning_radius"),
    86: ("exhibit_slots", "license_receipts"),
    87: ("artifact_context", "heritage_flags"),
    88: ("night_light_map", "crew_fatigue"),
    89: ("mural_grid", "artist_ids"),
    90: ("screen_angle", "seat_map"),
}


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
        require(type(value) is dict, f"{path}:not_object")
        props = schema["properties"]
        require(set(schema["required"]) <= set(value), f"{path}:missing")
        if schema.get("additional_properties") is False:
            require(set(value) <= set(props), f"{path}:unknown")
        for name, val in value.items():
            require(name in props, f"{path}:unknown_field")
            typed(val, props[name], f"{path}.{name}")
    elif kind == "array":
        require(type(value) is list, f"{path}:not_array")
        require(len(value) <= schema["max_items"], f"{path}:too_many")
        for i, item in enumerate(value):
            typed(item, schema["items"], f"{path}[{i}]")
        if schema.get("unique_items"):
            unique([json.dumps(x, sort_keys=True, allow_nan=False) for x in value],
                   f"{path}:duplicate")
        if schema.get("unique_by"):
            unique([x[schema["unique_by"]] for x in value],
                   f"{path}:duplicate_key")
    elif kind == "integer":
        require(type(value) is int, f"{path}:not_int")
        require(schema["min"] <= value <= schema["max"], f"{path}:out_of_bounds")
    elif kind == "boolean":
        require(type(value) is bool, f"{path}:not_bool")
    elif kind == "string":
        require(type(value) is str, f"{path}:not_string")
        require(schema["min_length"] <= len(value) <= schema["max_length"],
                f"{path}:length")
    else:
        raise InvalidState(f"{path}:unknown_schema_type")


def reachable(start: str, goals: set[str], links: list[dict]) -> bool:
    edges = defaultdict(list)
    for edge in links:
        if edge["open"]:
            edges[edge["from"]].append(edge["to"])
            edges[edge["to"]].append(edge["from"])
    q, seen = deque([start]), {start}
    while q:
        node = q.popleft()
        if node in goals:
            return True
        for nxt in edges[node]:
            if nxt not in seen:
                seen.add(nxt)
                q.append(nxt)
    return False


def rules(num: int, s: dict) -> None:
    if num == 81:
        nodes = {n["id"]: n for n in s["route_nodes"]}
        require(s["evac_origin"] in nodes, "evac_origin")
        require(all(n["elevation_cm"] > s["water_depth_cm"] for n in nodes.values()),
                "flooded_walkway")
        require(all(e["from"] in nodes and e["to"] in nodes and e["from"] != e["to"]
                    for e in s["links"]), "route_references")
        shelters = {n["id"] for n in nodes.values() if n["shelter"]}
        require(bool(shelters) and reachable(s["evac_origin"], shelters, s["links"]),
                "evacuation_reachability")
    elif num == 82:
        fuel = s["fuel_ledger"]
        require(fuel["credited"] == fuel["used"] + fuel["remaining"], "fuel_conservation")
        rooms = {r["id"]: r for r in s["rooms"]}
        require(all(r["exit_clear"] and r["heat_supply"] >= r["heat_demand"]
                    for r in rooms.values()), "shelter_heat_egress")
        counts = defaultdict(int)
        for person in s["occupants"]:
            require(person["consent"] and person["room_id"] in rooms, "occupant_consent")
            counts[person["room_id"]] += 1
        require(all(counts[rid] <= room["capacity"] for rid, room in rooms.items()),
                "shelter_capacity")
    elif num == 83:
        stages = {v["id"]: v for v in s["stages"]}
        require(all(v["current_load"] <= v["max_load"] and v["exit_clear"]
                    for v in stages.values()), "stage_load_egress")
        bookings = defaultdict(list)
        for p in s["performances"]:
            require(p["stage_id"] in stages and p["consent"], "stage_performer_consent")
            require(p["start_epoch"] < p["end_epoch"], "festival_window")
            require(p["attendance"] <= stages[p["stage_id"]]["capacity"], "festival_capacity")
            bookings[p["stage_id"]].append(p)
        for events in bookings.values():
            for i, a in enumerate(events):
                for b in events[i + 1:]:
                    require(a["end_epoch"] <= b["start_epoch"] or
                            b["end_epoch"] <= a["start_epoch"], "festival_double_booking")
    elif num == 84:
        plots = {p["id"]: p for p in s["plots"]}
        permits = {p["id"]: p for p in s["permissions"]}
        for plot in plots.values():
            require(plot["consent"] and not plot["protected"], "grove_guardian_protection")
        for dedication in s["dedications"]:
            plot = plots.get(dedication["plot_id"])
            perm = permits.get(dedication["permission_id"])
            require(plot is not None and perm is not None and perm["active"],
                    "dedication_authority")
            require(perm["plot_id"] == plot["id"] and
                    perm["author_id"] == dedication["author_id"], "dedication_identity")
    elif num == 85:
        towers = {t["id"]: t for t in s["towers"]}
        routes = {r["id"]: r for r in s["routes"]}
        for t in towers.values():
            require(t["powered"] and t["structure_ok"], "beacon_operation")
            require(t["visibility_route"] in routes and
                    routes[t["visibility_route"]]["visible"], "beacon_line_of_sight")
        event_keys = []
        for a in s["alerts"]:
            require(a["tower_id"] in towers and a["epoch"] <= s["day_epoch"],
                    "alert_provenance_epoch")
            event_keys.append((a["event_id"], a["epoch"]))
        unique(event_keys, "duplicate_storm_warning")
    elif num == 86:
        bays = {b["id"]: b for b in s["bays"]}
        counts = defaultdict(int)
        for work in s["works"]:
            require(work["bay_id"] in bays and work["consent"] and
                    work["rights_verified"], "art_license_consent")
            counts[work["bay_id"]] += 1
        require(all(b["exit_clear"] and counts[b["id"]] <= b["capacity"]
                    for b in bays.values()), "gallery_capacity_egress")
        bookings = defaultdict(list)
        for booking in s["bookings"]:
            require(booking["bay_id"] in bays and booking["permission"],
                    "gallery_booking_permission")
            require(booking["start_epoch"] < booking["end_epoch"], "gallery_booking_window")
            bookings[booking["bay_id"]].append(booking)
        for events in bookings.values():
            for i, a in enumerate(events):
                for b in events[i + 1:]:
                    require(a["end_epoch"] <= b["start_epoch"] or
                            b["end_epoch"] <= a["start_epoch"], "gallery_double_booking")
    elif num == 87:
        permits = {p["id"]: p for p in s["permits"]}
        zones = {z["id"]: z for z in s["zones"]}
        for zone in zones.values():
            p = permits.get(zone["permit_id"])
            require(not zone["protected"] and zone["surveyed"], "heritage_protection")
            require(zone["dig_depth_cm"] <= zone["max_depth_cm"], "heritage_depth")
            require(p is not None and p["active"] and p["zone_id"] == zone["id"],
                    "heritage_permit")
        unique([f["provenance_receipt"] for f in s["finds"]], "duplicate_find_receipt")
        require(all(f["zone_id"] in zones for f in s["finds"]), "orphan_find")
    elif num == 88:
        crews = {c["id"]: c for c in s["crews"]}
        for crew in crews.values():
            require(crew["consent"] and crew["fatigue"] <= crew["max_fatigue"],
                    "crew_consent_fatigue")
        shifts = defaultdict(list)
        for shift in s["shifts"]:
            require(shift["crew_id"] in crews and shift["epoch"] <= s["day_epoch"],
                    "shift_authority_epoch")
            require(shift["start_min"] >= 1080 or shift["start_min"] < 360,
                    "shift_night_window")
            require(shift["start_min"] + shift["duration_min"] <= 1440,
                    "shift_no_overnight_softlock")
            require(shift["lighting_lux"] >= 100 and shift["noise_permission"],
                    "night_safety_consent")
            require(shift["break_min"] <= shift["duration_min"], "break_window")
            shifts[(shift["crew_id"], shift["epoch"])].append(shift)
        for events in shifts.values():
            require(sum(x["duration_min"] for x in events) <= 480, "crew_daily_limit")
            for i, a in enumerate(events):
                for b in events[i + 1:]:
                    require(a["start_min"] + a["duration_min"] <= b["start_min"] or
                            b["start_min"] + b["duration_min"] <= a["start_min"],
                            "crew_double_shift")
    elif num == 89:
        panels = {p["id"]: p for p in s["panels"]}
        perms = {p["id"]: p for p in s["permissions"]}
        pigments = s["pigments"]
        require(pigments["credited"] == pigments["used"] + pigments["remaining"],
                "pigment_conservation")
        require(sum(t["pigment_used"] for t in s["tiles"]) == pigments["used"],
                "pigment_receipt_reconciliation")
        counts = defaultdict(int)
        for tile in s["tiles"]:
            p = perms.get(tile["permission_id"])
            require(tile["panel_id"] in panels and p is not None and p["active"],
                    "mural_panel_consent")
            require(p["artist_id"] == tile["artist_id"] and
                    p["panel_id"] == tile["panel_id"], "mural_authorship")
            counts[tile["panel_id"]] += 1
        require(all(counts[p["id"]] <= p["capacity"] for p in panels.values()),
                "mural_panel_capacity")
    elif num == 90:
        screens = {v["id"]: v for v in s["screens"]}
        for screen in screens.values():
            require(screen["accessible_seats"] <= screen["capacity"],
                    "accessible_capacity")
        bookings = defaultdict(list)
        for show in s["shows"]:
            screen = screens.get(show["screen_id"])
            require(screen is not None and screen["stable"] and screen["weather_safe"],
                    "screen_weather_structure")
            require(show["rights_verified"], "picturehouse_story_rights")
            require(show["epoch"] <= s["day_epoch"] and
                    show["start_min"] < show["end_min"], "picturehouse_window")
            require(show["attendees"] <= screen["capacity"] and
                    show["accessible_attendees"] <= screen["accessible_seats"] and
                    show["accessible_attendees"] <= show["attendees"],
                    "picturehouse_accessibility")
            bookings[(show["screen_id"], show["epoch"])].append(show)
        for events in bookings.values():
            for i, a in enumerate(events):
                for b in events[i + 1:]:
                    require(a["end_min"] <= b["start_min"] or
                            b["end_min"] <= a["start_min"], "picturehouse_double_booking")
    else:
        raise InvalidState("unknown_feature")


def validate(contract: dict, state: dict) -> None:
    typed(state, contract["save_contract"]["schema"])
    rules(int(contract["id"][-3:]), state)


def replace_path(obj, path, value) -> None:
    node = obj
    for key in path[:-1]:
        node = node[key]
    node[path[-1]] = value


def expect_rejected(contract, state, reason) -> None:
    try:
        validate(contract, state)
    except InvalidState:
        return
    raise AssertionError(f"{contract['id']}: unexpectedly accepted {reason}")


def leaf_paths(schema, value, path=()):
    kind = schema["type"]
    if kind == "object":
        for k, child in schema["properties"].items():
            yield from leaf_paths(child, value[k], path + (k,))
    elif kind == "array":
        if value:
            yield from leaf_paths(schema["items"], value[0], path + (0,))
    else:
        yield path, kind


def main() -> None:
    data = json.loads(DATA.read_text(encoding="utf-8"))
    contracts = data["state_contracts"]
    require(data["phaseC"].startswith("CLOSED"), "phase_gate")
    require([c["id"] for c in contracts] == EXPECTED, "exact_concept_ids")
    require(len({c["save_contract"]["namespace"] for c in contracts}) == 10,
            "namespace_uniqueness")
    valid = hostile = roundtrips = fuzz = 0
    rng = random.Random(20261102)
    all_receipts = []
    for contract in contracts:
        num = int(contract["id"][-3:])
        require(set(contract["source_field_mapping"]) == set(SOURCE_FIELDS[num]),
                "source_field_mapping")
        require(len(contract["valid_fixtures"]) == 2, "two_fixtures")
        require(len(contract["hostile_mutations"]) >= 4, "adversarial_coverage")
        require(bool(contract["player_verbs"]) and bool(contract["dependencies"]) and
                bool(contract["controls"]) and bool(contract["original_asset_plan"]) and
                bool(contract["performance_budget"]) and bool(contract["acceptance"]),
                "contract_completeness")
        for fixture in contract["valid_fixtures"]:
            validate(contract, fixture)
            valid += 1
            all_receipts.extend(fixture["receipts"])
            encoded = json.dumps(fixture, sort_keys=True, separators=(",", ":"),
                                 ensure_ascii=False, allow_nan=False)
            decoded = json.loads(encoded)
            validate(contract, decoded)
            require(decoded == fixture and json.dumps(decoded, sort_keys=True,
                    separators=(",", ":"), ensure_ascii=False) == encoded,
                    "deterministic_roundtrip")
            roundtrips += 1
        base = contract["valid_fixtures"][0]
        for mutation in contract["hostile_mutations"]:
            damaged = copy.deepcopy(base)
            replace_path(damaged, mutation["path"], mutation["value"])
            expect_rejected(contract, damaged, mutation["name"])
            hostile += 1
        generic = [
            ("missing_site", lambda s: s.pop("site_id")),
            ("unknown_field", lambda s: s.update({"injected": 1})),
            ("empty_site", lambda s: s.update(site_id="")),
            ("numeric_site", lambda s: s.update(site_id=42)),
            ("negative_revision", lambda s: s.update(revision=-1)),
            ("boolean_revision", lambda s: s.update(revision=True)),
            ("float_revision", lambda s: s.update(revision=1.2)),
            ("missing_epoch", lambda s: s.pop("day_epoch")),
            ("negative_epoch", lambda s: s.update(day_epoch=-1)),
            ("nan_epoch", lambda s: s.update(day_epoch=float("nan"))),
            ("overflow_epoch", lambda s: s.update(day_epoch=2**60)),
            ("duplicate_receipt", lambda s: s.update(receipts=["dup", "dup"])),
            ("receipt_wrong_type", lambda s: s.update(receipts="not_an_array")),
            ("empty_receipt_id", lambda s: s.update(receipts=[""])),
            ("receipt_object", lambda s: s.update(receipts=[{}])),
        ]
        for name, apply in generic:
            damaged = copy.deepcopy(base)
            apply(damaged)
            expect_rejected(contract, damaged, name)
            hostile += 1
        leaves = list(leaf_paths(contract["save_contract"]["schema"], base))
        require(bool(leaves), "fuzz_leaf_coverage")
        for i in range(24):
            path, kind = rng.choice(leaves)
            bad = {"integer": "invalid_integer", "boolean": "invalid_boolean",
                   "string": 12345}[kind]
            damaged = copy.deepcopy(base)
            replace_path(damaged, path, bad)
            expect_rejected(contract, damaged, f"seeded_leaf_{i}")
            fuzz += 1
        future = copy.deepcopy(base)
        future["day_epoch"] = 112
        validate(contract, future)
    unique(all_receipts, "cross_contract_duplicate_receipt")
    print(f"COMMUNITY_CONTRACTS={len(contracts)} VALID={valid} "
          f"HOSTILE_REJECTED={hostile} SEEDED_FUZZ_REJECTED={fuzz} "
          f"ROUNDTRIPS={roundtrips} TWO_YEAR_EPOCH_CHECKS={len(contracts)}")
    print("DESIGN_ONLY=TRUE NATIVE_GODOT_GAMEPLAY_PROOF=FALSE")


if __name__ == "__main__":
    main()
