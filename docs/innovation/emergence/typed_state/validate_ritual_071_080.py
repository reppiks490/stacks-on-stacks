#!/usr/bin/env python3
"""E03/E06/E18: deterministic, design-only E071-E080 ritual state contract QA.

No gameplay, inventory transfer, Village consent authority or Godot adapter is
implemented by this validator. All effects require future authoritative receipts.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

PATH = Path(__file__).with_name("ritual_071_080.json")
MAX_SAFE = 9007199254740991
EXPECTED = {
    71: "First Harvest Sharing Table",
    72: "Rain Gratitude Listening Walk",
    73: "Village Folk Melody Exchange",
    74: "Lantern River Farewell",
    75: "Community Welcome Circle",
    76: "Quiet Solstice Observatory",
    77: "Memory Ribbon Archive",
    78: "Culinary Heritage Vote",
    79: "Night Market Story Tokens",
    80: "Annual Theme Stewardship",
}


def typed(value, spec):
    if value is None:
        return spec.get("nullable") is True
    kind = spec["type"]
    if kind == "string":
        return type(value) is str and spec["min_length"] <= len(value) <= spec["max_length"]
    if kind == "integer":
        return type(value) is int and spec["min"] <= value <= min(spec["max"], MAX_SAFE)
    if kind == "boolean":
        return type(value) is bool
    if kind == "enum":
        return type(value) is str and value in spec["values"]
    if kind == "object":
        fields = spec["fields"]
        return type(value) is dict and set(value) == set(fields) and all(
            typed(value[key], sub) for key, sub in fields.items()
        )
    if kind == "list":
        if type(value) is not list or len(value) > spec["max_items"]:
            return False
        if not all(typed(item, spec["items"]) for item in value):
            return False
        key = spec.get("unique_by")
        if key:
            values = [
                json.dumps(item, sort_keys=True) if key == "$value" else item[key]
                for item in value
            ]
            if len(values) != len(set(values)):
                return False
        return True
    return False


def invariants(n, s):
    if n == 71:
        if not s["event_id"]:
            return s == {"event_id": "", "day_epoch": -1, "invitees": [],
                         "portion_ledger": [], "meal_memories": []}
        guests = {x["resident_id"]: x for x in s["invitees"]}
        portions = {x["portion_id"]: x for x in s["portion_ledger"]}
        return (s["day_epoch"] >= 1
                and len({x["food_receipt_id"] for x in s["portion_ledger"]})
                    == len(s["portion_ledger"])
                and all(x["resident_id"] in guests
                        and guests[x["resident_id"]]["consent"]
                        and x["diet_tag"] == guests[x["resident_id"]]["diet_tag"]
                        for x in s["portion_ledger"])
                and all(x["portion_id"] in portions
                        and x["resident_id"] == portions[x["portion_id"]]["resident_id"]
                        for x in s["meal_memories"]))
    if n == 72:
        if s["storm_epoch"] == -1:
            return s == {"storm_epoch": -1, "day_epoch": -1,
                         "weather_receipt": None, "participants": [], "stories": [],
                         "visibility": "private", "reward_receipt": None}
        consent = {x["resident_id"] for x in s["participants"] if x["consent"]}
        return (1 <= s["storm_epoch"] <= s["day_epoch"]
                and s["weather_receipt"] is not None
                and (s["reward_receipt"] is None or bool(s["stories"]))
                and all(x["resident_id"] in consent
                        and x["storm_epoch"] == s["storm_epoch"]
                        and (x["visibility"] != "public" or s["visibility"] == "public")
                        for x in s["stories"]))
    if n == 73:
        if not s["melody_id"]:
            return s == {"melody_id": "", "contributors": [], "notes": [],
                         "visibility": "private", "performance_receipt": None,
                         "playback_epoch": -1, "visual_fallback": True}
        return (bool(s["notes"]) and bool(s["contributors"])
                and s["visual_fallback"]
                and (s["visibility"] != "public"
                     or all(x["consent"] for x in s["contributors"]))
                and (s["performance_receipt"] is None
                     or (s["visibility"] == "public"
                         and s["playback_epoch"] >= 1))
                and (s["visibility"] != "private"
                     or s["performance_receipt"] is None))
    if n == 74:
        if not s["ceremony_id"]:
            return s == {"ceremony_id": "", "day_epoch": -1,
                         "light_instances": [], "escrow_receipts": [],
                         "return_receipts": [], "water_state": "clear"}
        lights = {x["light_id"]: x for x in s["light_instances"]}
        escrow = {x["light_id"] for x in s["escrow_receipts"]}
        returns = {x["light_id"] for x in s["return_receipts"]}
        return (s["day_epoch"] >= 1 and set(lights) == escrow
                and returns == {k for k, v in lights.items() if v["state"] == "returned"}
                and len({x["receipt_id"] for x in s["escrow_receipts"]})
                    == len(s["escrow_receipts"])
                and len({x["receipt_id"] for x in s["return_receipts"]})
                    == len(s["return_receipts"])
                and (s["water_state"] == "clear"
                     or not any(x["state"] == "floating" for x in s["light_instances"])))
    if n == 75:
        if not s["resident_id"]:
            return s == {"resident_id": "", "arrival_epoch": -1, "day_epoch": -1,
                         "consent": "pending", "ritual_receipt": None,
                         "reward_receipt": None, "invitation_count": 0}
        return (1 <= s["arrival_epoch"] <= s["day_epoch"]
                and s["invitation_count"] == 1
                and (s["consent"] != "accepted"
                     or s["ritual_receipt"] is not None)
                and (s["consent"] == "accepted"
                     or (s["ritual_receipt"] is None
                         and s["reward_receipt"] is None))
                and (s["reward_receipt"] is None
                     or s["ritual_receipt"] is not None))
    if n == 76:
        if s["year"] == 0:
            return s == {"year": 0, "day_epoch": -1, "attendees": [],
                         "mode": "captioned", "attendance_receipts": [],
                         "festival_clearance_receipt": None, "event_receipt": None}
        guests = {x["resident_id"]: x for x in s["attendees"]}
        return (s["day_epoch"] >= 1
                and s["year"] == (s["day_epoch"] - 1) // 56 + 1
                and s["event_receipt"] is not None
                and s["festival_clearance_receipt"] is not None
                and all(x["consent"] for x in s["attendees"])
                and len({x["receipt_id"] for x in s["attendance_receipts"]})
                    == len(s["attendance_receipts"])
                and all(x["resident_id"] in guests and x["year"] == s["year"]
                        for x in s["attendance_receipts"]))
    if n == 77:
        if not s["milestone_id"]:
            return s == {"milestone_id": "", "owner_id": "", "visibility": "private",
                         "archive_revision": 0, "content_digest": "",
                         "public_projection_receipt": None,
                         "retraction_receipt": None, "owner_consent": False}
        if not (s["owner_id"] and s["content_digest"] and s["archive_revision"] >= 1):
            return False
        if s["visibility"] == "public":
            return (s["owner_consent"] and s["public_projection_receipt"] is not None
                    and s["retraction_receipt"] is None)
        if s["visibility"] == "retracted":
            return (s["retraction_receipt"] is not None
                    and s["public_projection_receipt"] is None)
        return s["public_projection_receipt"] is None
    if n == 78:
        if s["season_epoch"] == -1:
            return s == {"season_epoch": -1, "day_epoch": -1, "ballots": [],
                         "chosen_recipe": "", "stock_receipts": [], "close_receipt": None}
        receipts = [x["receipt_id"] for x in s["ballots"]]
        return (1 <= s["season_epoch"] <= s["day_epoch"]
                and all(x["eligible"] and x["consent"] for x in s["ballots"])
                and len(receipts) == len(set(receipts))
                and (not s["chosen_recipe"]
                     or (s["chosen_recipe"] in {x["recipe_id"] for x in s["ballots"]}
                         and bool(s["stock_receipts"])
                         and s["close_receipt"] is not None))
                and (bool(s["chosen_recipe"])
                     or (not s["stock_receipts"] and s["close_receipt"] is None)))
    if n == 79:
        if not s["event_id"]:
            return s == {"event_id": "", "day_epoch": -1, "prompt_tokens": [],
                         "consent": [], "story_receipts": [], "currency_delta": 0}
        tokens = {x["token_id"]: x for x in s["prompt_tokens"]}
        consent = {x["resident_id"] for x in s["consent"] if x["allowed"]}
        used = [x["token_id"] for x in s["story_receipts"]]
        return (s["day_epoch"] >= 1 and s["currency_delta"] == 0
                and len(used) == len(set(used))
                and set(used) == {k for k, v in tokens.items() if v["spent"]}
                and all(x["token_id"] in tokens
                        and x["resident_id"] in consent
                        for x in s["story_receipts"]))
    if n == 80:
        if s["year"] == 0:
            return s == {"year": 0, "day_epoch": -1, "theme_vote": [],
                         "projects": [], "closing_receipt": None,
                         "bonus_points": 0, "event_booking_clearance": False}
        voters = {x["resident_id"]: x for x in s["theme_vote"]}
        total = sum(x["credit"] for x in s["projects"])
        return (s["day_epoch"] >= 1
                and s["year"] == (s["day_epoch"] - 1) // 56 + 1
                and all(x["consent"] for x in s["theme_vote"])
                and all(x["voluntary"] and x["contributor_id"] in voters
                        and x["theme_id"] == voters[x["contributor_id"]]["theme_id"]
                        for x in s["projects"])
                and total <= 10
                and (s["closing_receipt"] is None
                     and s["bonus_points"] == 0
                     or s["closing_receipt"] is not None
                     and s["event_booking_clearance"]
                     and s["bonus_points"] == total))
    return False


def validate(feature, state):
    return (type(state) is dict
            and set(state) == set(feature["fields"])
            and all(typed(state[key], spec) for key, spec in feature["fields"].items())
            and invariants(int(feature["id"][-3:]), state))


def wrong_type(spec):
    return {"string": 77, "integer": True, "boolean": 77, "enum": 77,
            "object": [], "list": {}}[spec["type"]]


def audit(data):
    assert data["schema_version"] == 1 and data["engine"] == "Godot 4.x"
    assert data["status"] == "design_only_non_authorizing"
    assert data["phaseC"] == "closed_pending_Principal_joint_220_approval"
    assert data["source"]["blob_sha"] == "eb7c590f43c92ded0e328ecfdf7003fa7c06ceac"
    features = data["state_contracts"]
    assert len(features) == 10
    assert [f["id"] for f in features] == [f"EB-E-{n:03d}" for n in EXPECTED]
    counts = {"valid": 0, "targeted_invalid": 0, "common_invalid": 0,
              "roundtrip": 0}
    for feature in features:
        n = int(feature["id"][-3:])
        assert feature["title"] == EXPECTED[n]
        assert feature["owner"] == "Emergence"
        assert feature["mission_ids"] == ["E03", "E06", "E18"]
        assert feature["phase"] == "design_only_no_runtime_implementation"
        assert feature["save_namespace"] == f"emergence.eb_e_{n:03d}"
        assert set(feature["source_field_mapping"]) == set(feature["source_fields"])
        assert set(feature["source_field_mapping"].values()) <= set(feature["fields"])
        assert len(feature["player_verbs"]) >= 4
        assert len(set(feature["player_verbs"])) == len(feature["player_verbs"])
        assert set(feature["controls"]) == {
            "keyboard_mouse", "controller", "touch", "accessibility"}
        assert set(feature["ui_feedback"]) == {
            "preview", "rejected", "accepted", "recovery"}
        assert feature["performance_budget"]["status"] == "proposed_not_measured"
        assert feature["original_asset_plan"] and feature["native_gate"]
        assert len(feature["positive_fixtures"]) == 2
        assert len(feature["negative_cases"]) >= 4
        for fixture in feature["positive_fixtures"]:
            state = fixture["state"]
            assert validate(feature, state), (feature["id"], fixture["name"], "valid")
            counts["valid"] += 1
            encoded = json.dumps(state, sort_keys=True, separators=(",", ":"),
                                 allow_nan=False)
            decoded = json.loads(encoded)
            assert decoded == state and validate(feature, decoded)
            assert json.dumps(decoded, sort_keys=True, separators=(",", ":")) == encoded
            counts["roundtrip"] += 1
        active = feature["positive_fixtures"][1]["state"]
        for case in feature["negative_cases"]:
            candidate = copy.deepcopy(active)
            candidate.update(copy.deepcopy(case["patch"]))
            assert not validate(feature, candidate), (
                feature["id"], case["name"], "targeted_invalid")
            counts["targeted_invalid"] += 1
        for key, spec in feature["fields"].items():
            missing = copy.deepcopy(active)
            del missing[key]
            assert not validate(feature, missing), (feature["id"], key, "missing")
            counts["common_invalid"] += 1
            malformed = copy.deepcopy(active)
            malformed[key] = wrong_type(spec)
            assert not validate(feature, malformed), (feature["id"], key, "wrong_type")
            counts["common_invalid"] += 1
            if spec["type"] == "integer":
                for invalid in (spec["min"] - 1, spec["max"] + 1, 1.5):
                    malformed = copy.deepcopy(active)
                    malformed[key] = invalid
                    assert not validate(feature, malformed), (feature["id"], key, "range")
                    counts["common_invalid"] += 1
            if spec["type"] == "list":
                malformed = copy.deepcopy(active)
                malformed[key] = [None] * (spec["max_items"] + 1)
                assert not validate(feature, malformed), (feature["id"], key, "overflow")
                counts["common_invalid"] += 1
                if active[key] and spec.get("unique_by"):
                    malformed = copy.deepcopy(active)
                    malformed[key].append(copy.deepcopy(active[key][0]))
                    assert not validate(feature, malformed), (
                        feature["id"], key, "duplicate")
                    counts["common_invalid"] += 1
                if active[key] and spec["items"]["type"] == "object":
                    malformed = copy.deepcopy(active)
                    malformed[key][0]["__unknown_nested__"] = True
                    assert not validate(feature, malformed), (
                        feature["id"], key, "unknown_nested")
                    counts["common_invalid"] += 1
        extra = copy.deepcopy(active)
        extra["__unknown__"] = 1
        assert not validate(feature, extra), (feature["id"], "unknown_field")
        counts["common_invalid"] += 1
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.parse_args()
    data = json.loads(PATH.read_text(encoding="utf-8"))
    counts = audit(data)
    print("DESIGN ONLY: E071-E080 optional ritual typed contracts; no gameplay integration")
    print(json.dumps(counts, sort_keys=True))


if __name__ == "__main__":
    main()
