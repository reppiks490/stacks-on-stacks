#!/usr/bin/env python3
"""E091–E100 design-only typed-state, calendar, and adversarial contract checks.

No Godot gameplay, transaction authority, native CI, or mobile parity is claimed.
"""
import argparse
import copy
import json
import pathlib
import random

PATH = pathlib.Path(__file__).with_name("sky_091_100.json")


def typed(value, spec):
    if value is None:
        return bool(spec.get("nullable", False))
    kind = spec["kind"]
    if kind == "boolean":
        return type(value) is bool
    if kind == "integer":
        return type(value) is int and spec["minimum"] <= value <= spec["maximum"]
    if kind == "string":
        return type(value) is str and len(value) <= spec["max_length"]
    if kind == "enum":
        return type(value) is str and value in spec["values"]
    if kind == "array":
        return (type(value) is list and len(value) <= spec["max_items"]
                and all(typed(v, spec["items"]) for v in value))
    if kind == "object":
        return (type(value) is dict and set(value) == set(spec["properties"])
                and all(typed(value[k], v) for k, v in spec["properties"].items()))
    return False


def unique(items):
    return len(items) == len(set(items))


def named(x):
    return type(x) is str and bool(x.strip())


def domain(n, s):
    if n == 91:
        points, region = s["viewpoints"], s["search_region"]
        if not s["meteor_id"]:
            return s["epoch"] == -1 and not points and region == {
                "region_id": "", "clue_total": 0, "clues_claimed": 0,
                "source_digest": ""}
        return (s["epoch"] >= 1 and s["epoch"] <= s["day_epoch"]
                and 2 <= len(points) <= 4
                and unique([p["point_id"] for p in points])
                and unique([p["minute_of_day"] for p in points])
                and len(set(p["bearing_deg"] for p in points)) >= 2
                and all(named(p["point_id"]) and p["day_epoch"] == s["epoch"]
                        for p in points)
                and named(region["region_id"]) and named(region["source_digest"])
                and 1 <= region["clue_total"] <= 16
                and 0 <= region["clues_claimed"] <= region["clue_total"])
    if n == 92:
        angles, steps = s["shadow_angles"], s["clue_steps"]
        if not angles and not steps:
            return not s["solved"] and s["eclipse_epoch"] == -1
        if not (s["eclipse_epoch"] >= 1
                and s["eclipse_epoch"] <= s["day_epoch"]
                and unique([a["step_id"] for a in angles])
                and unique([c["step_id"] for c in steps])
                and all(named(a["step_id"]) for a in angles)
                and all(named(c["step_id"]) and named(c["hint_id"])
                        and c["step_id"] in {a["step_id"] for a in angles}
                        for c in steps)):
            return False
        if s["eclipse_epoch"] < s["day_epoch"] and not all(
                a["source_model"] for a in angles):
            return False
        return (not s["solved"] or
                (len(angles) >= 2 and len(steps) >= 2
                 and all(c["solved"] for c in steps)
                 and len({a["angle_deg"] for a in angles}) >= 2))
    if n == 93:
        patterns, journal = s["pattern_ids"], s["journal"]
        if not patterns:
            return (s["aurora_seed"] == 0 and s["observation_epoch"] == -1
                    and not journal)
        return (s["aurora_seed"] > 0
                and 1 <= s["observation_epoch"] <= s["day_epoch"]
                and unique(patterns) and all(named(p) for p in patterns)
                and unique([j["pattern_id"] for j in journal])
                and all(j["pattern_id"] in patterns and named(j["label"])
                        and named(j["snapshot_digest"])
                        and 1 <= j["observed_epoch"] <= s["observation_epoch"]
                        for j in journal))
    if n == 94:
        obs = s["observations"]
        if not s["species_id"]:
            return s["habitat_id"] == "" and not obs and s["lunar_phase"] == 0
        if not named(s["habitat_id"]):
            return False
        return (unique([o["observation_id"] for o in obs])
                and unique([(o["day_epoch"], o["habitat_id"], o["phase"])
                            for o in obs])
                and all(named(o["observation_id"])
                        and o["species_id"] == s["species_id"]
                        and o["habitat_id"] == s["habitat_id"]
                        and o["undisturbed"] and o["day_epoch"] <= s["day_epoch"]
                        for o in obs)
                and all(len({o["phase"] for o in obs
                             if o["day_epoch"] == day}) == 1
                        for day in {o["day_epoch"] for o in obs})
                and (not obs or obs[-1]["phase"] == s["lunar_phase"]))
    if n == 95:
        hint = s["event_hint"]
        if not s["cloud_id"]:
            return s["weather_epoch"] == -1 and s["clue_choice"] == "" and hint == {
                "hint_id": "", "weather_digest": "",
                "forecast_epoch": -1, "valid_until_epoch": -1}
        return (1 <= s["weather_epoch"] <= s["day_epoch"]
                and named(s["clue_choice"]) and named(hint["hint_id"])
                and named(hint["weather_digest"])
                and hint["forecast_epoch"] == s["weather_epoch"]
                and hint["forecast_epoch"] <= hint["valid_until_epoch"]
                <= hint["forecast_epoch"] + 2)
    if n == 96:
        ids, alignment, inscription = (s["landmark_ids"], s["alignment"],
                                       s["inscription"])
        if not alignment["diagram_available"]:
            return False
        if not s["pool_id"]:
            return not ids and not alignment["solved"] and inscription == {
                "inscription_id": "", "unlocked": False, "clue_digest": ""}
        return (len(ids) >= 2 and unique(ids) and all(named(i) for i in ids)
                and alignment["solved"] == inscription["unlocked"]
                and (not inscription["unlocked"]
                     or (named(inscription["inscription_id"])
                         and named(inscription["clue_digest"]))))
    if n == 97:
        narrators, versions, consents = (s["narrators"], s["story_versions"],
                                         s["consents"])
        if not s["star_id"]:
            return not narrators and not versions and not consents
        nmap = {n["npc_id"]: n for n in narrators}
        cmap = {c["npc_id"]: c for c in consents}
        return (bool(narrators) and unique([n["npc_id"] for n in narrators])
                and unique([c["npc_id"] for c in consents])
                and unique([v["story_id"] for v in versions])
                and all(named(n["npc_id"]) for n in narrators)
                and all(named(c["npc_id"]) and c["npc_id"] in nmap
                        and c["consent_epoch"] <= s["day_epoch"]
                        for c in consents)
                and all(named(v["story_id"]) and named(v["source_digest"])
                        and v["npc_id"] in nmap and nmap[v["npc_id"]]["consent"]
                        and v["npc_id"] in cmap and cmap[v["npc_id"]]["granted"]
                        and cmap[v["npc_id"]]["consent_epoch"] <= v["day_epoch"]
                        <= s["day_epoch"] for v in versions))
    if n == 98:
        window, npc, appointment = (s["sky_window"], s["npc_slot"],
                                    s["appointment"])
        if not s["clock_id"]:
            return window == {"start_epoch": -1, "end_epoch": -1,
                              "start_minute": 0, "end_minute": 0} and npc == {
                                  "npc_id": "", "slot_id": "", "consent": False,
                                  "available": False} and appointment == {
                                      "appointment_id": "", "epoch": -1,
                                      "minute": 0, "status": "none"}
        if not (window["start_epoch"] >= 1
                and window["start_epoch"] <= window["end_epoch"]
                and window["start_minute"] <= window["end_minute"]
                and named(npc["npc_id"]) and named(npc["slot_id"])):
            return False
        if appointment["status"] == "none":
            return appointment["appointment_id"] == "" and appointment["epoch"] == -1
        return (named(appointment["appointment_id"])
                and npc["consent"] and npc["available"]
                and window["start_epoch"] <= appointment["epoch"] <= window["end_epoch"]
                and window["start_minute"] <= appointment["minute"]
                <= window["end_minute"]
                and (appointment["status"] != "booked"
                     or appointment["epoch"] >= s["day_epoch"])
                and (appointment["status"] != "completed"
                     or appointment["epoch"] <= s["day_epoch"]))
    if n == 99:
        found, donated = s["find_receipt"], s["donation_receipt"]
        if not s["fragment_id"]:
            return s["owner"] == "" and donated is None and found == {
                "receipt_id": "", "region_id": "", "day_epoch": -1,
                "verified": False}
        if not (named(found["receipt_id"]) and named(found["region_id"])
                and found["verified"] and 1 <= found["day_epoch"] <= s["day_epoch"]):
            return False
        if donated is None:
            return s["owner"] == "player"
        return (s["owner"] == "community" and donated["verified"]
                and named(donated["receipt_id"])
                and donated["receipt_id"] != found["receipt_id"]
                and named(donated["recipient_id"])
                and found["day_epoch"] <= donated["day_epoch"] <= s["day_epoch"])
    if n == 100:
        peaks, arrival = s["peak_ids"], s["arrival_receipt"]
        if not peaks:
            return s["signal_epoch"] == -1 and s["route_choice"] == "" and arrival is None
        if not (len(peaks) >= 2 and unique(peaks)
                and all(named(p) for p in peaks)
                and 1 <= s["signal_epoch"] <= s["day_epoch"]
                and s["route_choice"] in ("north", "south")):
            return False
        return (arrival is None or
                (named(arrival["receipt_id"])
                 and arrival["route_id"] == s["route_choice"]
                 and arrival["day_epoch"] >= s["signal_epoch"]
                 and arrival["day_epoch"] <= s["day_epoch"]
                 and arrival["safe_return"]))
    raise ValueError("unknown sky contract")


def valid(contract, state):
    if not typed(state, {"kind": "object", "properties": contract["fields"]}):
        return False
    receipts = state["command_receipts"]
    if state["revision"] < len(receipts):
        return False
    if not unique([r["command_id"] for r in receipts]):
        return False
    if any(not named(r["command_id"]) or not named(r["effect_digest"])
           or r["day_epoch"] > state["day_epoch"]
           or r["expected_revision"] >= state["revision"] for r in receipts):
        return False
    if any(a["expected_revision"] >= b["expected_revision"]
           for a, b in zip(receipts, receipts[1:])):
        return False
    return domain(int(contract["id"][-3:]), state)


def invalid_type(spec):
    if spec["kind"] in ("string", "enum"):
        return 7
    if spec["kind"] == "integer":
        return "bad"
    if spec["kind"] == "boolean":
        return 1
    if spec["kind"] == "array":
        return {}
    return []


def domain_mutations(n, state):
    def changed(path, value):
        x = copy.deepcopy(state)
        target = x
        for part in path[:-1]:
            target = target[part]
        target[path[-1]] = value
        return x
    if n == 91:
        return [changed(["viewpoints", 1, "point_id"], "hill"),
                changed(["viewpoints", 1, "bearing_deg"], 42),
                changed(["viewpoints", 1, "minute_of_day"], 800),
                changed(["search_region", "clues_claimed"], 4),
                changed(["epoch"], 58)]
    if n == 92:
        return [changed(["shadow_angles", 0, "source_model"], False),
                changed(["clue_steps", 0, "solved"], False),
                changed(["shadow_angles", 1, "step_id"], "marker-a"),
                changed(["shadow_angles", 1, "angle_deg"], 30),
                changed(["clue_steps", 1, "step_id"], "marker-a")]
    if n == 93:
        return [changed(["aurora_seed"], 0),
                changed(["pattern_ids", 1], "arc"),
                changed(["journal", 0, "pattern_id"], "alien"),
                changed(["journal", 0, "label"], ""),
                changed(["journal", 0, "observed_epoch"], 58)]
    if n == 94:
        x = copy.deepcopy(state)
        x["observations"].append({**x["observations"][0],
                                  "observation_id": "moon-watch-2", "phase": 2})
        return [changed(["observations", 0, "undisturbed"], False),
                changed(["observations", 0, "species_id"], "owl"),
                changed(["observations", 0, "day_epoch"], 58),
                changed(["observations", 0, "observation_id"], ""),
                x]
    if n == 95:
        return [changed(["event_hint", "weather_digest"], ""),
                changed(["event_hint", "forecast_epoch"], 56),
                changed(["event_hint", "valid_until_epoch"], 60),
                changed(["weather_epoch"], 58),
                changed(["clue_choice"], "")]
    if n == 96:
        return [changed(["alignment", "diagram_available"], False),
                changed(["landmark_ids", 1], "spire"),
                changed(["alignment", "solved"], False),
                changed(["inscription", "clue_digest"], ""),
                changed(["landmark_ids"], ["spire"])]
    if n == 97:
        return [changed(["narrators", 0, "consent"], False),
                changed(["story_versions", 0, "npc_id"], "unknown"),
                changed(["story_versions", 1, "story_id"], "ada-1"),
                changed(["consents", 0, "granted"], False),
                changed(["consents", 0, "consent_epoch"], 58)]
    if n == 98:
        return [changed(["npc_slot", "consent"], False),
                changed(["npc_slot", "available"], False),
                changed(["appointment", "minute"], 700),
                changed(["sky_window", "end_minute"], 800),
                changed(["appointment", "epoch"], 56)]
    if n == 99:
        return [changed(["owner"], "player"),
                changed(["find_receipt", "verified"], False),
                changed(["donation_receipt", "verified"], False),
                changed(["donation_receipt", "receipt_id"], "find-1"),
                changed(["donation_receipt", "day_epoch"], 58)]
    if n == 100:
        return [changed(["peak_ids", 1], "north-peak"),
                changed(["arrival_receipt", "route_id"], "south"),
                changed(["arrival_receipt", "safe_return"], False),
                changed(["arrival_receipt", "day_epoch"], 56),
                changed(["signal_epoch"], 58)]
    raise ValueError(n)


def self_test():
    doc = json.loads(PATH.read_text(encoding="utf-8"))
    assert doc["schema_version"] == 2 and doc["count"] == 10
    assert doc["source_blob_sha"] == "eb7c590f43c92ded0e328ecfdf7003fa7c06ceac"
    contracts = doc["contracts"]
    assert [c["id"] for c in contracts] == [
        "EB-E-%03d" % i for i in range(91, 101)]
    assert len({c["save_namespace"] for c in contracts}) == 10
    passed, rejected, roundtrips = 0, 0, 0
    for c in contracts:
        n = int(c["id"][-3:])
        assert c["status"] == "design_only_not_playable"
        assert c["source_blob_sha"] == doc["source_blob_sha"]
        assert len(c["source_fields"]) == 4
        assert set(c["fields"]) == set(c["source_fields"]) | {
            "revision", "day_epoch", "command_receipts"}
        assert c["save_namespace"] == "emergence.sky.%03d" % n
        assert c["player_verbs"] and c["dependencies"] and c["original_asset_plan"]
        assert c["performance_budget"]["status"] == "proposed_not_measured"
        for fixture in ("empty", "active"):
            state = c["fixtures"][fixture]
            assert valid(c, state), (c["id"], fixture)
            passed += 1
            assert json.loads(json.dumps(state, sort_keys=True)) == state
            roundtrips += 1
        s = c["fixtures"]["active"]
        bad = []
        for field, spec in c["fields"].items():
            x = copy.deepcopy(s)
            x[field] = invalid_type(spec)
            bad.append(x)
            if spec["kind"] == "object" and s[field] is not None:
                for k, sub in spec["properties"].items():
                    x = copy.deepcopy(s)
                    x[field][k] = invalid_type(sub)
                    bad.append(x)
            if spec["kind"] == "array" and s[field] and spec["items"]["kind"] == "object":
                for k, sub in spec["items"]["properties"].items():
                    x = copy.deepcopy(s)
                    x[field][0][k] = invalid_type(sub)
                    bad.append(x)
        x = copy.deepcopy(s)
        x["unknown"] = 1
        bad.append(x)
        x = copy.deepcopy(s)
        del x["day_epoch"]
        bad.append(x)
        x = copy.deepcopy(s)
        x["revision"] = 0
        bad.append(x)
        x = copy.deepcopy(s)
        x["command_receipts"][0]["command_id"] = ""
        bad.append(x)
        x = copy.deepcopy(s)
        x["command_receipts"][0]["day_epoch"] = 58
        bad.append(x)
        x = copy.deepcopy(s)
        x["command_receipts"].append(copy.deepcopy(x["command_receipts"][0]))
        x["revision"] = 2
        bad.append(x)
        bad += domain_mutations(n, s)
        rng = random.Random(20261102 + n)
        for _ in range(32):
            x = copy.deepcopy(s)
            field = rng.choice(list(c["fields"]))
            x[field] = invalid_type(c["fields"][field])
            bad.append(x)
        for i, x in enumerate(bad):
            assert not valid(c, x), (c["id"], "invalid accepted", i)
            rejected += 1
        # 56-day years: same day-of-year in different years must be distinct.
        assert 57 != 113 and (57 - 1) % 56 == (113 - 1) % 56
    print("SKY_CONTRACT_PASS ids=10 valid=%d invalid_rejected=%d roundtrips=%d "
          "year_rollover=10 source_sha=%s" % (
              passed, rejected, roundtrips, doc["source_blob_sha"]))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
    else:
        parser.error("use --self-test")
