#!/usr/bin/env python3
"""E03/E10/E18 design-only typed companion state and adversarial fixture validator.

No Godot gameplay or authoritative save/inventory mutation is implemented here.
"""
from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path

PATH = Path(__file__).with_name("companion_061_070.json")
MAX_SAFE = 9007199254740991
EXPECTED = {
    61: "Scent Mosaic Tracker",
    62: "Rescue Bark Triangulation",
    63: "Herd Whisper Formation",
    64: "Comfort Companion Signals",
    65: "Burrow-Safe Treasure Sniff",
    66: "Weather-Savvy Companion Shelter",
    67: "Trail Partnership Rotation",
    68: "Companion Gesture Lexicon",
    69: "Wildlife Distance Etiquette",
    70: "Senior Companion Mentorship",
}


def typed(value, spec):
    if value is None:
        return spec.get("nullable") is True
    kind = spec.get("type")
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
            typed(value[k], sub) for k, sub in fields.items()
        )
    if kind == "list":
        if type(value) is not list or len(value) > spec["max_items"]:
            return False
        if not all(typed(item, spec["items"]) for item in value):
            return False
        unique = spec.get("unique_by")
        if unique:
            keys = [json.dumps(item, sort_keys=True) if unique == "$value" else item[unique]
                    for item in value]
            if len(keys) != len(set(keys)):
                return False
        return True
    return False


def invariants(n, s):
    if n == 61:
        if not s["companion_id"]:
            return s == {"companion_id": "", "scent_samples": [], "confidence": 0,
                         "rest_epoch": -1, "training_receipts": []}
        return (bool(s["scent_samples"]) and s["rest_epoch"] >= 1
                and s["rest_epoch"] >= max(x["epoch"] for x in s["scent_samples"])
                and s["confidence"] <= 20 * len(s["scent_samples"])
                and len(s["training_receipts"]) <= len(s["scent_samples"]))
    if n == 62:
        if not s["rescue_target"]:
            return s == {"alert_ids": [], "search_area": "", "rescue_target": "",
                         "completion": None, "reachable": False, "stamina_cost": 0,
                         "safe_clue_mode": "visual", "target_epoch": -1}
        return (bool(s["search_area"]) and len(s["alert_ids"]) >= 2
                and s["target_epoch"] >= 1 and s["reachable"]
                and s["stamina_cost"] > 0 and s["completion"] is not None)
    if n == 63:
        if not s["companion_id"]:
            return s == {"companion_id": "", "waypoints": [], "herd_consent": [],
                         "route_receipt": None, "assigned_elsewhere": [], "day_epoch": -1}
        consent = set(s["herd_consent"])
        unavailable = set(s["assigned_elsewhere"])
        return (s["day_epoch"] >= 1 and bool(s["waypoints"])
                and s["route_receipt"] is not None
                and all(w["approved"] and w["animal_id"] in consent
                        and w["animal_id"] not in unavailable for w in s["waypoints"]))
    if n == 64:
        if not s["companion_id"]:
            return s == {"companion_id": "", "stress_level": 0, "care_receipts": [],
                         "training_pause": False, "rest_epoch": -1, "stress_before_care": 0}
        relief = sum(x["relief"] for x in s["care_receipts"])
        return (s["rest_epoch"] >= 1 and relief <= 20
                and all(x["epoch"] <= s["rest_epoch"] for x in s["care_receipts"])
                and relief <= s["stress_before_care"]
                and s["stress_level"] == s["stress_before_care"] - relief
                and (s["stress_level"] < 60 or s["training_pause"]))
    if n == 65:
        if not s["companion_id"]:
            return s == {"companion_id": "", "search_cells": [], "protected_dens": [],
                         "find_receipts": [], "companion_fatigue": 0, "day_epoch": -1}
        cells = {c["cell_id"]: c for c in s["search_cells"]}
        return (s["day_epoch"] >= 1 and bool(cells)
                and set(s["protected_dens"]) == {k for k,v in cells.items() if v["protected"]}
                and s["companion_fatigue"] >= sum(c["searched"] for c in cells.values())
                and len({r["receipt_id"] for r in s["find_receipts"]}) == len(s["find_receipts"])
                and all(r["cell_id"] in cells and cells[r["cell_id"]]["searched"]
                        and not cells[r["cell_id"]]["protected"] for r in s["find_receipts"]))
    if n == 66:
        if not s["companion_id"]:
            return s == {"companion_id": "", "forecast_epoch": -1, "shelter_choice": "none",
                         "care_status": "idle", "shelter_available": False,
                         "warning_receipt": None, "day_epoch": -1}
        return (s["forecast_epoch"] >= 1 and s["day_epoch"] >= s["forecast_epoch"]
                and s["shelter_available"]
                and (s["shelter_choice"] == "none"
                     or (s["warning_receipt"] is not None
                         and s["care_status"] in ("resting", "safe"))))
    if n == 67:
        if not s["active_id"]:
            return s == {"active_id": "", "standby_id": "", "rotation_epoch": -1,
                         "energy_ledger": [], "trail_segments": [],
                         "pending_action": False, "swap_receipt": None}
        energy = {e["companion_id"]: e["energy"] for e in s["energy_ledger"]}
        receipts = [x["receipt_id"] for x in s["trail_segments"]]
        return (s["rotation_epoch"] >= 1 and s["standby_id"] != s["active_id"]
                and bool(s["standby_id"]) and s["active_id"] in energy
                and s["standby_id"] in energy and energy[s["active_id"]] > 0
                and len(receipts) == len(set(receipts))
                and all(x["companion_id"] in energy for x in s["trail_segments"])
                and not (s["pending_action"] and s["swap_receipt"] is not None))
    if n == 68:
        if not s["companion_id"]:
            return s == {"companion_id": "", "gesture_map": [], "learned_cues": [],
                         "request_history": [], "consent": False, "visual_fallback": True}
        mapped = {g["cue_id"] for g in s["gesture_map"]}
        learned = set(s["learned_cues"])
        return (s["consent"] and s["visual_fallback"]
                and all(r["cue_id"] in mapped and r["cue_id"] in learned
                        for r in s["request_history"]))
    if n == 69:
        if not s["species_id"]:
            return s == {"species_id": "", "companion_id": "", "safety_radius_cm": 0,
                         "companion_distance_cm": 0, "observations": [],
                         "protected_nest": False, "reward_kind": "none", "day_epoch": -1}
        return (bool(s["companion_id"]) and s["day_epoch"] >= 1
                and s["protected_nest"] and s["safety_radius_cm"] > 0
                and s["companion_distance_cm"] >= s["safety_radius_cm"]
                and all(x["epoch"] <= s["day_epoch"] for x in s["observations"])
                and s["reward_kind"] == ("knowledge_only" if s["observations"] else "none"))
    if n == 70:
        if not s["mentor_id"]:
            return s == {"mentor_id": "", "learner_id": "", "session_receipts": [],
                         "skill_progress": 0, "welfare_ok": False,
                         "canceled": False, "day_epoch": -1}
        completed = [x for x in s["session_receipts"] if x["completed"]]
        return (bool(s["learner_id"]) and s["mentor_id"] != s["learner_id"]
                and s["day_epoch"] >= 1
                and all(x["epoch"] <= s["day_epoch"] for x in s["session_receipts"])
                and all(x["skill_delta"] == 0 for x in s["session_receipts"]
                        if not x["completed"])
                and s["skill_progress"] == sum(x["skill_delta"] for x in completed)
                and (not completed or s["welfare_ok"])
                and (not s["canceled"] or (not completed and s["skill_progress"] == 0)))
    return False


def validate(feature, state):
    return (type(state) is dict and set(state) == set(feature["fields"])
            and all(typed(state[k], spec) for k, spec in feature["fields"].items())
            and invariants(int(feature["id"][-3:]), state))


def wrong_type(spec):
    kind = spec["type"]
    return {"string": 77, "integer": True, "boolean": 77, "enum": 77,
            "object": [], "list": {}}[kind]


def audit(data):
    assert data["schema_version"] == 1 and data["engine"] == "Godot 4.x"
    assert data["status"] == "design_only_non_authorizing"
    assert data["phaseC"] == "closed_pending_Principal_joint_220_approval"
    assert data["source"]["commit"] == "63cab5d05c742c61205933482e38fac2a4086764"
    fs = data["state_contracts"]
    assert len(fs) == 10
    assert [x["id"] for x in fs] == [f"EB-E-{i:03d}" for i in EXPECTED]
    counts = {"valid": 0, "targeted_invalid": 0, "common_invalid": 0, "roundtrip": 0}
    for f in fs:
        n = int(f["id"][-3:])
        assert f["title"] == EXPECTED[n] and f["owner"] == "Emergence"
        assert f["phase"] == "design_only_no_runtime_implementation"
        assert f["mission_ids"] == ["E03", "E10", "E18"]
        assert f["save_namespace"] == f"emergence.eb_e_{n}"
        assert set(f["source_field_mapping"]) == set(f["source_fields"])
        assert set(f["source_field_mapping"].values()).issubset(set(f["fields"]))
        assert len(f["player_verbs"]) >= 4 and len(set(f["player_verbs"])) == len(f["player_verbs"])
        assert any(f["title"].lower().split()[0] in verb for verb in f["player_verbs"])
        assert f["source_projection_blocker"] if n == 69 else f["source_projection_blocker"] is None
        assert f["performance_budget"]["status"] == "proposed_not_measured"
        assert set(f["controls"]) == {"keyboard_mouse", "controller", "touch", "accessibility"}
        assert len(f["positive_fixtures"]) == 2 and len(f["negative_cases"]) >= 4
        assert all(f["player_scenario"] and f["original_asset_plan"] and f["native_gate"]
                   for _ in (0,))
        for fixture in f["positive_fixtures"]:
            state = fixture["state"]
            assert validate(f, state), (f["id"], fixture["name"], "valid")
            counts["valid"] += 1
            serialized = json.dumps(state, sort_keys=True, separators=(",", ":"), allow_nan=False)
            assert json.loads(serialized) == state
            assert validate(f, json.loads(serialized))
            assert json.dumps(json.loads(serialized), sort_keys=True, separators=(",", ":")) == serialized
            counts["roundtrip"] += 1
        active = f["positive_fixtures"][1]["state"]
        for case in f["negative_cases"]:
            candidate = copy.deepcopy(active)
            candidate.update(copy.deepcopy(case["patch"]))
            assert not validate(f, candidate), (f["id"], case["name"], "targeted_invalid")
            counts["targeted_invalid"] += 1
        for k, spec in f["fields"].items():
            missing = copy.deepcopy(active)
            del missing[k]
            assert not validate(f, missing), (f["id"], k, "missing")
            counts["common_invalid"] += 1
            malformed = copy.deepcopy(active)
            malformed[k] = wrong_type(spec)
            assert not validate(f, malformed), (f["id"], k, "wrong_type")
            counts["common_invalid"] += 1
            if spec["type"] == "integer":
                for bad in (spec["min"] - 1, spec["max"] + 1, 1.5):
                    malformed = copy.deepcopy(active)
                    malformed[k] = bad
                    assert not validate(f, malformed), (f["id"], k, "range")
                    counts["common_invalid"] += 1
            if spec["type"] == "list":
                malformed = copy.deepcopy(active)
                malformed[k] = [copy.deepcopy(active[k][0])] * (spec["max_items"] + 1) if active[k] else [None]
                assert not validate(f, malformed), (f["id"], k, "oversized_or_bad_element")
                counts["common_invalid"] += 1
                if active[k] and spec.get("unique_by"):
                    malformed = copy.deepcopy(active)
                    malformed[k].append(copy.deepcopy(active[k][0]))
                    assert not validate(f, malformed), (f["id"], k, "duplicate")
                    counts["common_invalid"] += 1
        extra = copy.deepcopy(active)
        extra["__unknown__"] = 1
        assert not validate(f, extra), (f["id"], "unknown_field")
        counts["common_invalid"] += 1
    return counts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    data = json.loads(PATH.read_text(encoding="utf-8"))
    counts = audit(data)
    print("DESIGN ONLY: E061-E070 typed companion contracts; no gameplay integration")
    print(json.dumps(counts, sort_keys=True))
    if not args.self_test:
        print("Pass --self-test to explicitly run all fixture checks (also run above).")


if __name__ == "__main__":
    main()
