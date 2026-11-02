#!/usr/bin/env python3
"""EVERBLOOM E03/E04/E18: deterministic DESIGN-ONLY typed-state audit.

This does not implement gameplay, mutate saves, authorize Phase C, or prove native Godot.
"""
from __future__ import annotations

import argparse
import copy
import json
import math
from pathlib import Path

ROOT = Path(__file__).with_name("causal_011_020.json")
SAFE_MAX = 9007199254740991
SOURCE_FIELDS = {
    "EB-E-011": ["forecast_id", "slot_epoch", "reservation_id", "shift_count"],
    "EB-E-012": ["region_id", "extraction_receipts", "ecology_debt", "repair_receipts"],
    "EB-E-013": ["message_id", "relay_hops", "weather_epoch", "delivery_state"],
    "EB-E-014": ["event_epoch", "early_start", "fatigue_debt", "reward_receipt"],
    "EB-E-015": ["clue_ids", "observation_epoch", "thaw_epoch", "verdict"],
    "EB-E-016": ["habitat_ids", "survey_epoch", "confidence", "report_id"],
    "EB-E-017": ["project_id", "world_revision", "choice_receipt", "effect_receipts"],
    "EB-E-018": ["season_log", "read_cursor", "causal_links", "snapshot_revision", "playback_mode"],
    "EB-E-019": ["shelter_id", "capacity", "assignments", "alternatives"],
    "EB-E-020": ["event_id", "deadline_minute", "choice", "expired_fallback"],
}
RULES = {
    "requires", "nonnegative_when", "zero_if_absent", "requires_if_nonempty",
    "sum_lte", "requires_enum_when", "positive_if", "requires_if_present",
    "ordered_epoch_when", "requires_nonempty_when", "confidence_coverage",
    "requires_nonempty_when_present", "requires_if_enum", "count_lte",
    "distinct_nested", "disjoint_nested", "cursor_lte_length",
    "links_reference_events", "true_only_when",
}


def typed(value, spec):
    if value is None:
        return spec.get("nullable", False) is True
    kind = spec.get("type")
    if kind == "string":
        return isinstance(value, str) and len(value) <= spec.get("max_length", 0) and len(value) >= spec.get("min_length", 0)
    if kind == "boolean":
        return type(value) is bool
    if kind == "integer":
        return type(value) is int and spec.get("min", 1) <= value <= min(spec.get("max", -1), SAFE_MAX)
    if kind == "number":
        return type(value) in (int, float) and math.isfinite(value) and spec.get("min", 1) <= value <= spec.get("max", -1)
    if kind == "enum":
        return isinstance(value, str) and value in spec.get("values", [])
    if kind == "object":
        fields = spec.get("fields", {})
        return (type(value) is dict and set(value) == set(fields)
                and all(typed(value[k], s) for k, s in fields.items()))
    if kind == "list":
        if type(value) is not list or len(value) > spec.get("max_items", -1):
            return False
        if not all(typed(item, spec.get("items", {})) for item in value):
            return False
        unique = spec.get("unique_by")
        if unique:
            keys = [item if unique == "$value" else item.get(unique) for item in value]
            return len(set(keys)) == len(keys)
        # String receipt/observation IDs must never be counted more than once.
        if spec.get("items", {}).get("type") == "string":
            return len(set(value)) == len(value)
        return True
    return False


def rules_ok(state, rules):
    for rule in rules:
        code = rule["code"]
        if code not in RULES:
            return False
        if code == "requires":
            if state.get(rule["when"]) and any(not state.get(k) for k in rule["fields"]):
                return False
        elif code == "nonnegative_when":
            if state.get(rule["when"]) and state[rule["field"]] < 0:
                return False
        elif code == "zero_if_absent":
            if not state.get(rule["when"]) and state[rule["field"]] != 0:
                return False
        elif code == "requires_if_nonempty":
            if state[rule["list"]] and not state.get(rule["field"]):
                return False
        elif code == "sum_lte":
            a = sum(item[rule["field"]] for item in state[rule["numerator"]])
            b = sum(item[rule["field"]] for item in state[rule["denominator"]])
            if a > b:
                return False
        elif code == "requires_enum_when":
            if state[rule["field"]] == rule["value"] and rule["condition"] == "empty" and state[rule["other"]]:
                return False
        elif code == "positive_if":
            if state[rule["when"]] and state[rule["field"]] <= 0:
                return False
        elif code == "requires_if_present":
            if state.get(rule["field"]) and not state.get(rule["when"]):
                return False
        elif code == "ordered_epoch_when":
            if state[rule["when"]] == rule["value"]:
                if state[rule["before"]] < 0 or state[rule["after"]] < 0 or state[rule["before"]] >= state[rule["after"]]:
                    return False
        elif code == "requires_nonempty_when":
            if state[rule["when"]] == rule["value"] and not state[rule["list"]]:
                return False
        elif code == "confidence_coverage":
            if state[rule["field"]] > len(state[rule["list"]]) * rule["per_unique"] + 1e-9:
                return False
        elif code == "requires_nonempty_when_present":
            if state.get(rule["when"]) and not state[rule["list"]]:
                return False
        elif code == "requires_if_enum":
            if state[rule["field"]] in rule["values"] and not state.get(rule["required"]):
                return False
        elif code == "count_lte":
            if len(state[rule["list"]]) > state[rule["field"]]:
                return False
        elif code == "distinct_nested":
            ids = [item[rule["field"]] for item in state[rule["list"]]]
            if len(ids) != len(set(ids)):
                return False
        elif code == "disjoint_nested":
            left = {item[rule["field"]] for item in state[rule["left"]]}
            right = {item[rule["field"]] for item in state[rule["right"]]}
            if left & right:
                return False
        elif code == "cursor_lte_length":
            if state[rule["cursor"]] > len(state[rule["list"]]):
                return False
        elif code == "links_reference_events":
            ids = {item["event_id"] for item in state[rule["list"]]}
            if any(link["from_id"] not in ids or link["to_id"] not in ids for link in state[rule["links"]]):
                return False
        elif code == "true_only_when":
            if state[rule["field"]] and state[rule["when"]] != rule["value"]:
                return False
    return True


def validate_state(record, state):
    """Missing optional namespace is valid; present malformed state fails closed."""
    if state is None:
        return True
    if type(state) is not dict or set(state) != set(record["fields"]):
        return False
    return (all(typed(state[k], spec) for k, spec in record["fields"].items())
            and rules_ok(state, record["rules"]))


def default_state(record):
    return {name: copy.deepcopy(spec["default"]) for name, spec in record["fields"].items()}


def validate_catalog(data):
    if data.get("schema_version") != 1 or data.get("phaseC") != "closed_pending_Principal_joint_220_approval":
        raise ValueError("phase gate or schema")
    if data.get("source", {}).get("blob_sha") != "a5def76918e77e0ded7e3e8085444698b4e0b549":
        raise ValueError("source provenance")
    records = data.get("state_contracts", [])
    if len(records) != 10 or [r.get("id") for r in records] != list(SOURCE_FIELDS):
        raise ValueError("missing/duplicate/unsorted records")
    if len({r.get("save_namespace") for r in records}) != 10:
        raise ValueError("namespace collision")
    count_fields = 0
    count_rules = 0
    for rec in records:
        rid = rec["id"]
        additions = ["deadline_epoch", "settlement_receipt"] if rid == "EB-E-020" else []
        if rec.get("source_fields") != SOURCE_FIELDS[rid] or rec.get("additions") != additions:
            raise ValueError("unapproved field drift")
        if list(rec["fields"]) != SOURCE_FIELDS[rid] + additions:
            raise ValueError("typed field order or coverage")
        if rec.get("state_version") != (2 if additions else 1):
            raise ValueError("migration version")
        if rec.get("phase") != "design_only_no_runtime_implementation" or rec.get("owner") != "Emergence":
            raise ValueError("ownership")
        if not rec.get("migration") or not rec.get("negative") or not rec.get("native_gate"):
            raise ValueError("incomplete contract")
        if not rec.get("rules") or not all(r.get("code") in RULES for r in rec["rules"]):
            raise ValueError("unknown/missing invariants")
        if not validate_state(rec, default_state(rec)):
            raise ValueError("invalid default state: " + rid)
        count_fields += len(rec["fields"])
        count_rules += len(rec["rules"])
    return count_fields, count_rules


def negative_tests(data):
    cases = 0
    def reject(candidate):
        nonlocal cases
        try:
            validate_catalog(candidate)
        except (ValueError, TypeError, KeyError):
            cases += 1
            return
        raise AssertionError("invalid catalog accepted")
    for edit in ("id", "version", "source", "fields", "phase"):
        altered = copy.deepcopy(data)
        r = altered["state_contracts"][0]
        if edit == "id": r["id"] = "EB-E-999"
        elif edit == "version": r["state_version"] = 99
        elif edit == "source": altered["source"]["blob_sha"] = "forged"
        elif edit == "fields": r["fields"].pop("shift_count")
        elif edit == "phase": altered["phaseC"] = "open"
        reject(altered)
    for rec in data["state_contracts"]:
        valid = default_state(rec)
        assert validate_state(rec, valid)
        assert validate_state(rec, None)  # optional absent namespace
        for field, spec in rec["fields"].items():
            altered = copy.deepcopy(valid)
            altered[field] = {"not": "a valid scalar or array"}
            assert not validate_state(rec, altered), (rec["id"], field)
            cases += 1
        altered = copy.deepcopy(valid)
        altered["unapproved"] = 1
        assert not validate_state(rec, altered)
        cases += 1
    by_id = {r["id"]: r for r in data["state_contracts"]}
    tests = {
        "EB-E-011": [("reservation_id", "r1")],
        "EB-E-012": [("repair_receipts", [{"id":"x","amount":1,"epoch":1}])],
        "EB-E-013": [("relay_hops", [{"relay_id":"a","epoch":1,"state":"pending"}])],
        "EB-E-014": [("early_start", True)],
        "EB-E-015": [("verdict", "protected")],
        "EB-E-016": [("confidence", 0.5)],
        "EB-E-017": [("effect_receipts", ["effect1"])],
        "EB-E-018": [("read_cursor", 1)],
        "EB-E-019": [("assignments", [{"npc_id":"n","bed_index":0,"epoch":1}])],
        "EB-E-020": [("event_id", "sunset_1")],
    }
    for rid, edits in tests.items():
        rec = by_id[rid]
        state = default_state(rec)
        for field, value in edits: state[field] = value
        assert not validate_state(rec, state), rid
        cases += 1
    # Additional nested and cross-field adversarial cases.
    r = by_id["EB-E-019"]
    state = default_state(r)
    state.update(shelter_id="hall", capacity=2, assignments=[
        {"npc_id":"a","bed_index":0,"epoch":1},
        {"npc_id":"b","bed_index":0,"epoch":1}])
    assert not validate_state(r, state); cases += 1
    state["assignments"][1]["bed_index"] = 1
    state["alternatives"] = [{"npc_id":"a","route_id":"home"}]
    assert not validate_state(r, state); cases += 1
    r = by_id["EB-E-018"]
    state = default_state(r)
    state["causal_links"] = [{"from_id":"fake","to_id":"fake"}]
    assert not validate_state(r, state); cases += 1
    r = by_id["EB-E-020"]
    state = default_state(r)
    state.update(event_id="sunset", deadline_epoch=15, choice="accepted")
    assert not validate_state(r, state); cases += 1
    r = by_id["EB-E-016"]
    state = default_state(r)
    state["habitat_ids"] = ["h1", "h1"]
    assert not validate_state(r, state); cases += 1
    return cases


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    data = json.loads(ROOT.read_text(encoding="utf-8"))
    fields, rules = validate_catalog(data)
    print(f"EMERGENCE DESIGN AUDIT: {len(data['state_contracts'])} typed feature contracts; {fields} fields; {rules} cross-field rules")
    if args.self_test:
        count = negative_tests(data)
        print(f"EMERGENCE DESIGN AUDIT: {count} deliberately invalid cases rejected; 0 harness failures")
    print("DESIGN-ONLY PASS; no Godot runtime/gameplay or Principal Phase-C approval claimed")


if __name__ == "__main__":
    main()
